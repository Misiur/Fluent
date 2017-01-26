package fluent;

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;

import fluent.FluentParent;

using haxe.macro.ComplexTypeTools;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using Lambda;

class Macro
{
    public static function build()
    {
        var printer = new Printer();

        var cls, p;
        switch(Context.getLocalType()) {
            case TInst(c, [t]): {
                cls = c.get();
                p = t;
            }
            default: throw 'assert';
        }

        var wrapperName = cls.name;

        var wrappedParams = [];
        var wrapped = switch(p) {
            case TInst(_.get() => tcls, tp): {
                wrappedParams = tp;
                tcls;
            }
            default: throw 'assert';
        }

        var clsname = cls.name + wrapped.name;

        try {
            return Context.getType(clsname).toComplexType();
        } catch(e:String) {
            //Proceed as usual
        }
    
        var wrappedType = {
            name: wrapped.module.substring(wrapped.module.lastIndexOf(".") + 1),
            pack: wrapped.pack,
            sub: wrapped.name,
            params: typeParametersToTypeParams(wrapped.params, wrappedParams)
        };

        var fields:Map<String, ClassField> = new Map();

        inline function fishMethods(type:ClassType) {
            for(field in type.fields.get()) {
                switch(field.kind) {
                    case FMethod(f): {
                        if(!fields.exists(field.name)) {
                            fields.set(field.name, field);
                        }
                    }
                    default: null;
                }
            }
        };

        fishMethods(wrapped);

        var parent = wrapped.superClass;
        while(parent != null) {
            var type = parent.t.get();
            fishMethods(type);
            parent = type.superClass;
        }

        var path = TPath(wrappedType);

        var constructorArgs = [];
        var wrappedConstructorArgs = [];
        var constructor = Context.getTypedExpr(wrapped.constructor.get().expr());
        switch(constructor.expr) {
            case EFunction(_, e): {
                constructorArgs = e.args;
                wrappedConstructorArgs = e.args.map(function(e) { return macro $i{e.name}; });
            }
            default: throw 'assert';
        }

        var def = macro class $clsname implements fluent.FluentParent #if fluent_dynamic implements Dynamic #end
        {
            private var __base:$path;
            private var __parent:Null<Dynamic>;

            public function new() //Dynamically added arguments lower in this file
            {
                if(meta != null) {
                    if(meta.parent != null) {
                        __parent = meta.parent;
                    }
                    if(meta.instance != null) {
                        __base = meta.instance;
                    } else {
                        __base = new $wrappedType($a{wrappedConstructorArgs});
                    }
                } else {
                    __base = new $wrappedType($a{wrappedConstructorArgs});
                }
            }

            public function get()
            {
                return __base;
            }

            public function end()
            {
                if(__parent == null) {
                    throw 'Already reached top level';
                }

                return __parent;
            }
        };

        //Add arguments to new()
        mergeConstructorArguments(def, constructorArgs, path);
        //Create Proxy for wrapped class functions
        mapFunctions(def, fields, wrapped, wrappedType);

        #if fluent_debug
        trace(printer.printTypeDefinition(def));
        #end
        Context.defineType(def);

        return Context.getType(clsname).toComplexType();
    }

    private static function typeParametersToTypeParams(parameters:Array<TypeParameter>, types:Array<Type>):Array<TypeParam>
    {
        var params:Array<TypeParam> = [];
        for(i in 0...parameters.length) {
            params.push(TPType(types[i].toComplexType()));
        }

        return params;
    }

    private static function mergeConstructorArguments(def:TypeDefinition, args:Array<FunctionArg>, wrappedPath:ComplexType)
    {
        var constructor;

        for(field in def.fields) {
            if(field.name == 'new') {
                switch(field.kind) {
                    case FFun(f): {
                        constructor = f;
                    }
                    default: throw 'assert';
                }
            }
        }

        if(constructor == null) {
            throw 'assert';
        }

        var arguments = args.map(function(arg) { return macro $i{arg.name}; });

        var metaStructure = macro : { parent:fluent.FluentParent, instance:$wrappedPath };

        args.unshift({
            name: 'meta',
            type: metaStructure,
            opt: true
        });

        constructor.args = constructor.args.concat(args);
    }

    private static function mapFunctions(def:TypeDefinition, fields:Map<String, ClassField>, wrapped:ClassType, wrappedType:TypePath)
    {
        for(key in fields.keys()) {
            var field = fields[key];
            var fluent = false;
            var fieldExpr = Context.getTypedExpr(field.expr());
            var isPublic = field.isPublic;
            var isResolve = key == 'resolve';

            for(meta in field.meta.get()) {
                if(meta.name == 'Fluent') {
                    fluent = true;
                    break;
                }
            }

            var body = switch(fieldExpr.expr) {
                case EFunction(_, f): f;
                default: throw 'assert';
            }

            var arguments = body.args.map(function(arg) {
                return macro $i{arg.name};
            });

            var newBody:Expr;
            var type = Context.follow(field.type);
            var access = isPublic ? APublic : APrivate;

            if(fluent) {
                var wrapperArguments = (macro { parent: this, instance: instance });
                var allArguments = arguments.copy();
                allArguments.unshift(wrapperArguments);

                var wrappedType = switch(type) {
                    case TFun(_, t): {
                        switch(t) {
                            case TInst(_.get() => v, p): TPath({
                                name: v.module.substring(v.module.lastIndexOf(".") + 1),
                                pack: v.pack,
                                sub: v.name
                            });
                            default: null;
                        }
                    }
                    default: null;
                };

                //Make sure that number of arguments is correct to clear up error messages
                assertFluentArguments(wrappedType, arguments, field.name, wrapped);

                newBody = macro {
                    var instance = __base.$key($a{arguments});

                    return new fluent.Fluent<$wrappedType>($a{allArguments});
                };
            } #if fluent_dynamic else if (isResolve) {
                newBody = body.expr;
            } #end else {
                //Invert, so Void is false, non-void is true - this way code is more readable
                var ret = !switch(type) {
                    case TFun(_, t): {
                        switch(t) {
                            case TAbstract(_.get() => v, _): v.name == 'Void';
                            default: false;
                        }
                    }
                    default: false;
                };

                if(!ret) {
                    newBody = macro {
                        __base.$key($a{arguments});

                        return this;
                    };
                } else {
                    newBody = macro {
                        return __base.$key($a{arguments});
                    };
                }
            }

            var meta:Metadata = [];
            if(!isPublic) {
                var path = [].concat(wrappedType.pack);
                //Gods are CRAZY I tell you. For some reason we need to disregard module
                // path.push(wrappedType.name);
                path.push(wrappedType.sub);
                path.push(field.name);

                meta.push({
                    name: ':access',
                    params: [macro $p{path}],
                    pos: Context.currentPos()
                });
            }

            def.fields.push({
                name: key,
                access: [access],
                meta: meta,
                kind: FFun({
                    expr: newBody,
                    args: body.args,
                    ret: null
                }),
                pos: Context.currentPos()
            });
        }
    }

    private static function assertFluentArguments(wrappedType:ComplexType, arguments:Array<Expr>, fieldName:String, wrapped:ClassType)
    {
        var type = wrappedType.toType();
        var typeName:String;
        var constructorArgs = switch(type) {
            case TInst(_.get() => e, _): {
                typeName = e.name;

                switch(e.constructor.get().expr().expr) {
                    case TFunction(f): f.args;
                    default: throw 'assert';
                }
            }
            default: throw 'assert';
        }

        if(arguments.length > constructorArgs.length) {
            var wrappedName = wrapped.pack.join('.') + '.' + wrapped.name;
            throw 'Too many arguments passed to $typeName in $wrappedName#$fieldName';
        }
    }
}
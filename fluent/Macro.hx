package fluent;

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;

import fluent.FluentParent;

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
                        if(field.isPublic && !fields.exists(field.name)) {
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

        var clsname = cls.name + wrapped.name;
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

        var def = macro class $clsname implements fluent.FluentParent 
        {
            private var __base:$path;
            private var __parent:Null<fluent.FluentParent>;

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

        mergeConstructorArguments(def, constructorArgs, path);
        mapFunctions(def, fields);

        trace(printer.printTypeDefinition(def));
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

    private static function mapFunctions(def:TypeDefinition, fields:Map<String, ClassField>)
    {
        for(key in fields.keys()) {
            var field = fields[key];
            var fluent = false;
            var fieldExpr = Context.getTypedExpr(field.expr());

            for(meta in field.meta.get()) {
                if(meta.name == 'Fluent') {
                    fluent = true;
                    break;
                }
            }

            var body;

            switch(fieldExpr.expr) {
                case EFunction(_, f): {
                    body = f;
                }
                default: throw 'assert';
            }

            var arguments = body.args.map(function(arg) {
                return macro $i{arg.name};
            });

            var newBody:Expr;
            var type = Context.follow(field.type);

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

                newBody = macro {
                    var instance = __base.$key($a{arguments});

                    return new fluent.Fluent<$wrappedType>($a{allArguments});
                };
            } else {
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

            def.fields.push({
                name: key,
                access: [APublic],
                kind: FFun({
                    expr: newBody,
                    args: body.args,
                    ret: null
                }),
                pos: Context.currentPos()
            });
        }
    }
}
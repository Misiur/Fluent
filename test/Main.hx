package test;

import fluent.Fluent;

class Main
{
    private static function main()
    {
        var a = new Fluent<Foo>(2.5);
        a.donger().stronger();
    }
}

class RootFoo
{
    public function donger()
    {
        trace('Donger!');
    }
}

class ParentFoo extends RootFoo
{
    public function stronger()
    {
        trace('Stronger!');
    }
}

class Foo extends ParentFoo
{
    private var foo:Float;

    public function new(foo:Float)
    {
        this.foo = foo;
    }


    private function notCopied()
    {
        trace("Can't access this");
    }

    public function normal()
    {
        trace("Normal function");
    }

    public function returning()
    {
        trace("Returning functon");
        return 2 + 2;
    }

    @Fluent
    public function fluent()
    {
        return new Bar();        
    }
}

class Bar
{
    public function new(arg:String = 'Yay')
    {
        trace(arg);
    }
}
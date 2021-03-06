package test;

import fluent.Fluent;

class Main
{
    public static function main()
    {
        var foo = new Fluent<Foo>();

        var returnedValue = foo
            .hello() //Hello
            .alias()
                .hi('You') //Hi You!
            .end()
            .bar().end()
            .listBars() //A bar, A bar
            .returner()
        ;
        //returnedValue == 4
    }
}

class Foo implements Dynamic
{
    private var bars:Array<Bar> = new Array();

    public function new() {}

    public function listBars()
    {
        trace(bars.join(', '));
    }

    public function hello()
    {
        trace('Hello');
    }

    public function returner()
    {
        return 2 + 2;
    }

    @Fluent
    public function bar()
    {
        var bar = new Bar();
        bars.push(bar);

        return bar;
    }

    @Fluent
    private function aliasBar()
    {        
        var bar = new Bar();
        bars.push(bar);

        return bar;   
    }

    public function resolve(field:String):Dynamic
    {
        if(field == 'alias') {
            return aliasBar;
        }

        throw 'Nonexistent method';
    }
}

class Bar
{
    public function new() {}

    public function hi(who:String)
    {
        trace('Hi $who!');
    }

    public function toString()
    {
        return 'A bar';
    }
}
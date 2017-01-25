# Fluent
This is a library for creating fluent interfaces over existing classes. Uses `@:genericBuild`.

## Quick start
```haxe
import fluent.Fluent;

class Main
{
    public static function main()
    {
        var foo = new Fluent<Foo>();
        var returnedValue = foo
            .hello() //Hello
            .bar()
                .hi('You') //Hi You!
            .end()
            .bar().end()
            .listBars() //A bar, A bar
            .returner()
        ;
        //returnedValue == 4
    }
}

class Foo
{
    private var bars:Array<Bar>;

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
```
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

## Flags
There are two flags you can use
`-D fluent_debug` - will dump out bodies of generated classes
`-D fluent_dynamic` - allows extending your API, of course is costly and further hinders any type-completion you might have
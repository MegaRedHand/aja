# Aja

[![Hex Version](https://img.shields.io/hexpm/v/aja.svg)](https://hex.pm/packages/aja)
[![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/aja/)
[![CI](https://github.com/sabiwara/aja/workflows/CI/badge.svg)](https://github.com/sabiwara/aja/actions?query=workflow%3ACI)

Extension of the Elixir standard library focused on data stuctures and data manipulation.

**WARNING: Aja is still a work in progress.**
APIs might still change at any point.

## TL;DR

The Elixir standard library is so rich, ergonomic and well-documented that it feels there is not much left to add.
And yet... some occasional friction might still remain.

Aja aims to remove some of this friction by providing mostly:
- non-existing (e.g. ordered maps) or currently hard-to-use (e.g. binary search trees) data structures written in pure elixir
- nice-to-have utility functions

### Data structures

Friction can occur when the provided data structures do not satisfy the needs
of a specific algorithm, be it for functionality or performance reasons.
Sometimes, a linked-list just won't cut it. In the
[words of Okasaki](https://www.cs.cmu.edu/~rwh/theses/okasaki.pdf):

> "there is one aspect of functional programming that no amount of cleverness on the part of the
  compiler writer is likely to mitigate — the use of inferior or inappropriate data structures."

Order maps (`A.OrdMap`s) are probably Aja's killer feature, since:
- regular maps do not keep track of the insertion order
- keywords do not have the right performance characteristics and only support atoms

```elixir
iex> Map.new([{"one", 1}, {"two", 2}, {"three", 3}]) |> Enum.to_list()
[{"one", 1}, {"three", 3}, {"two", 2}]
iex> ord_map = A.OrdMap.new([{"one", 1}, {"two", 2}, {"three", 3}])
#A<ord(%{"one" => 1, "two" => 2, "three" => 3})>
iex> ord_map["two"]
2
iex> Enum.to_list(ord_map)
[{"one", 1}, {"two", 2}, {"three", 3}]
```

Order maps behave pretty much like regular maps, and the `A.OrdMap` module
offers the same API as `Map`.
They come with a convenience macro `A.ord/1` to construct and pattern-match upon, which should
make them a breeze to use without much added friction over plain maps:

```elixir
iex> A.OrdMap.new(%{"一" => 1, "二" => 2, "三" => 3})  # without macro: insertion order is lost!
#A<ord(%{"一" => 1, "三" => 3, "二" => 2})>
iex> import A
iex> ord_map = ord(%{"一" => 1, "二" => 2, "三" => 3})  # insertion order is preserved!
#A<ord(%{"一" => 1, "二" => 2, "三" => 3})>
iex> ord(%{"三" => three, "一" => one}) = ord_map
iex> {one, three}
{1, 3}
```

Maps and sets based on Red-Black Trees (`A.RBMap` and `A.RBSet`) are useful when you want to
keep a collection sorted.

```elixir
iex> A.RBMap.new([b: "Bat", a: "Ant", c: "Cat", b: "Buffalo"])
#A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat"}>
iex> A.RBSet.new([6, 6, 7, 7, 4, 1, 2, 3, 1, 5])
#A.RBSet<[1, 2, 3, 4, 5, 6, 7]>
```

They offer similar functionalities as general balanced trees ([`:gb_trees`](https://erlang.org/doc/man/gb_trees.html)
and [`:gb_sets`](https://erlang.org/doc/man/gb_sets.html)) included in the Erlang standard library.
`A.RBMap` and `A.RBSet` should however offer better performance, and be more convenient to use.

All those data structures offer:
- good performance characteristics at any size (see [FAQ](#faq))
- well-documented APIs that are consistent with the standard library
- implementation of `Inspect`, `Enumerable` and `Collectable` protocols
- (except for sets) implementation of the `Access` behaviour
- (optional if `Jason` is installed) implemention the `Jason.Encoder` protocol


### Utility functions

**Don't Break The Pipe!**

```elixir
iex> %{foo: "bar"} |> A.Pair.wrap(:noreply)
{:noreply, %{foo: "bar"}}
iex> {:ok, 55} |> A.Pair.unwrap!(:ok)
55
```

Exclusive ranges (`A.ExRange`)

```elixir
iex> A.ExRange.new(0, 10) |> Enum.to_list()
[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
iex> import A
iex> Enum.map(0 ~> 5, &"id_#{&1}")
["id_0", "id_1", "id_2", "id_3", "id_4"]
```

Other helper examples:

```elixir
iex> A.IO.iodata_empty?(["", []])
true
iex> A.Integer.decimal_format(1234567)
"1,234,567"
iex> A.Integer.div_rem(7, 3)
{2, 1}
iex> A.List.repeatedly(&:rand.uniform/0, 3)
[0.40502929729990744, 0.45336720247823126, 0.04094511692041057]
```

None of this is revolutionary, but having these helpers to hand might save you the implementation
and the testing, or bringing over a library just for this one thing.

All those helpers should provide some rationale in their documentation as to why they might
be useful and what pain point they are addressing.

Browse the API documentation to see if you find something that helps you.

## Installation

Aja can be installed by adding `aja` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aja, "~> 0.1.2"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/aja](https://hexdocs.pm/aja).

## About Aja

### Inspirations

- the amazingly polished [Elixir standard library](https://hexdocs.pm/elixir): self-consistent,
  well-documented and just **delightful** ✨️
- the also amazing [Python standard library](https://docs.python.org/3/library/),
  notably its [collection](https://docs.python.org/3/library/collections.html) module
- the amazing [lodash](https://lodash.com/docs) which complements nicely the (historically rather small)
  javascript standard library, with a very consistent API
- work on efficient immutable data structures, spearheaded by
  [Chris Okasaki](https://www.cs.cmu.edu/~rwh/theses/okasaki.pdf)

### Goals

- like the standard library, being **delightful** to use ✨️ (consistency, quality, documentation)
- no external dependency to help you preserve a decent dependency tree and fast compile times
- performance-conscious (right algorithm, proper benchmarking, fast compile times)
- mostly dead-simple pure functions: no configuration, no mandatory macro, no statefulness / OTP
- **Don't Break The Pipe!**: APIs have been designed with pipe-ability in mind

### Non-goals

- add every possible feature that has not been accepted in elixir core (Aja is opinionated!)
- wrap everything and remove the need to know Erlang
- touching anything OTP-related / stateful

## FAQ

### How is the performance?

Performance for maps is still far from native maps (roughly 4 times slower insertions) or ETS (mutable state).

Aja data structures are implemented in plain erlang/elixir and cannot compete with native code yet.

However:
- `A.RBMap` / `A.OrdMap` / `A.RBSet` perform better than the also non-native `:gb_trees` / `:gb_sets` modules
- the performance gap is consistent and doesn't degrade with the size (logarithmic time complexity)
- with the [JIT compilation](https://github.com/erlang/otp/pull/2745) coming to the BEAM,
  we can expected the gap with native code to be reduced in the upcoming months.

Aja data structures should work fine in most cases, but if you're considering them for
performance-critical sections of your code, make sure to benchmark them and also consider alternatives,
typically ETS if mutable state is acceptable.

Benchmarking is still a work in progress, but you can check the
[`bench` folder](https://github.com/sabiwara/aja/blob/main/bench) for more detailed figures.

### Why is there a convenience macro for `A.OrdMap` but not for other structures?

There are actually two reasons for this:
1. ordered maps would be unconvenient to initialize otherwise
2. ordered maps can be pattern-matched upon due to their internal representation, tree-based structures cannot

#### 1. Initialization with `new/1`:

Ordered maps are tricky to initialize, and `A.OrdMap.new/1` is not convenient to do so.
We cannot simply pass it a map, because the map will reorder the keys.
We have to pass it a list of tuples, which is fine if keys are atoms, but feels messy and not readable otherwise.

Being a macro, `A.ord/1` is able to read the code and preserve the order, without ever
instanciating a map that would lose the order:

```elixir
iex> A.OrdMap.new(%{"one" => 1, "two" => 2, "three" => 3})
#A<ord(%{"one" => 1, "three" => 3, "two" => 2})>
iex> ord(%{"one" => 1, "two" => 2, "three" => 3})
#A<ord(%{"one" => 1, "two" => 2, "three" => 3})>
```

`A.RBMap.new/1`, `A.RBSet.new/1` ... do not face any similar constraints and wouldn't benefit from a macro.

#### 2. Pattern-matching

Short answer: because the internal representation of ordered maps happens to use a map, it is possible
to make `A.ord/1` work as it does. Tree-based `A.RBMap`s cannot enjoy this treatment.

Longer answer: Elixir (Erlang) is limited in what can be pattern-matched upon, because it does not offer
[active patterns](https://docs.microsoft.com/en-us/dotnet/fsharp/language-reference/active-patterns).
While this is a fine decision that helps keeping the language simpler, it has the drawback of being tied
to the internal representation of data structures.

Quoting [Okasaki](https://www.cs.cmu.edu/~rwh/theses/okasaki.pdf) again, describing what might be
called pattern-matching induced damage:

> "Ironically, pattern matching — one of the most popular features in functional programming languages —
  is also one of the biggest obstacles to the widespread use of efficient functional data structures.
  The problem is that pattern matching can only be performed on data structures whose representation is
  known, yet the basic software-engineering principle of abstraction tells us that the representation
  of non-trivial data structures should be hidden. The seductive allure of pattern matching leads many
  functional programmers to abandon sophisticated data structures in favor of simple, known
  representations such as lists, even when doing so causes an otherwise linear algorithm to explode to
  quadratic or even exponential time."

Making pattern-matching work for trees would probably need to implement some kind of active pattern,
that would imply to redefine alternative versions of `def`, `case` and `=/2`.

### Does Aja try to do too much?

The Unix philosophy of *"Do one thing and do it well"* is arguably the right approach in many cases.
Aja doesn't really follow it, but there are conscious reasons for going that direction.

While it might be possible later down the road to split some of its components, there is no plan to do so
at the moment.

First, we don't think there is any real downside of shipping "too much": Aja has and aims to keep
a lightweight footprint and fast compile times, as well as a modular structure.
You can just use what you need without suffering from what you don't.

This lodash-like approach has benefits too: it aims to ship with a lot of convenience while introducing only
one flat dependency. This can help staying out of two extreme paths:

- the ["leftpad way"](https://www.theregister.com/2016/03/23/npm_left_pad_chaos/), where every project relies on
  a ton of small dependencies, ending up with un-manageable dependency trees and brittle software.
- the ["Lisp Curse way"](http://winestockwebdesign.com/Essays/Lisp_Curse.html), where everybody keeps rewriting
  the same thing over and over because nobody wants the extra dependency. Being a hidden Lisp with similar
  super powers and expressiveness, Elixir might make it relatively easy and tempting to go down that path.

### What are the next steps?

Nothing is set in stone, but the next steps will probably be:
- keep working towards production-readiness: testing, improve documentation
- more benchmarks and performance optimizations
- add an `OrderedSet`
- add a queue or a dequeue (wrap `:queue`?)
- evaluate Kahrs algorithm as an alternative for red-black tree deletion
- evaluate some other interesting data structures to add
  ([clojure's vectors](https://hypirion.com/musings/understanding-persistent-vector-pt-1)
  or some equivalent?)

## Copyright and License

Aja is licensed under the [MIT License](LICENSE.md).

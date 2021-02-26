defmodule A.OrdMap do
  @moduledoc ~S"""
  A map preserving key insertion order, with efficient lookups, updates and enumeration.

  It works like regular maps, except that the insertion order is preserved:

      iex> %{"one" => 1, "two" => 2, "three" => 3}
      %{"one" => 1, "three" => 3, "two" => 2}
      iex> A.OrdMap.new([{"one", 1}, {"two", 2}, {"three", 3}])
      #A<ord(%{"one" => 1, "two" => 2, "three" => 3})>

  There is an unavoidable overhead compared to natively implemented maps, so
  keep using regular maps when you do not care about the insertion order.

  `A.OrdMap`:
  - provides efficient (logarithmic) access: it is not a simple list of tuples
  - implements the `Access` behaviour, `Enum` / `Inspect` / `Collectable` protocols
  - optionally implements the `Jason.Encoder` protocol if `Jason` is installed

  ## Examples

  `A.OrdMap` offers the same API as `Map` :

      iex> ord_map = A.OrdMap.new([b: "Bat", a: "Ant", c: "Cat"])
      #A<ord(%{b: "Bat", a: "Ant", c: "Cat"})>
      iex> A.OrdMap.get(ord_map, :c)
      "Cat"
      iex> A.OrdMap.fetch(ord_map, :a)
      {:ok, "Ant"}
      iex> A.OrdMap.put(ord_map, :d, "Dinosaur")
      #A<ord(%{b: "Bat", a: "Ant", c: "Cat", d: "Dinosaur"})>
      iex> A.OrdMap.put(ord_map, :b, "Buffalo")
      #A<ord(%{b: "Buffalo", a: "Ant", c: "Cat"})>
      iex> A.OrdMap.delete(ord_map, :b)
      #A<ord(%{a: "Ant", c: "Cat"}, sparse?: true)>
      iex> Enum.to_list(ord_map)
      [b: "Bat", a: "Ant", c: "Cat"]
      iex> [d: "Dinosaur", b: "Buffalo", e: "Eel"] |> Enum.into(ord_map)
      #A<ord(%{b: "Buffalo", a: "Ant", c: "Cat", d: "Dinosaur", e: "Eel"})>

  ## Specific functions

  Due to its ordered nature, `A.OrdMap` also offers some extra methods not present in `Map`, like:
  - `first/1` and `last/1` to efficiently retrieve the first / last key-value pair
  - `foldl/3` and `foldr/3` to efficiently fold (reduce) from left-to-right or right-to-left

  Examples:

      iex> ord_map = A.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      iex> A.OrdMap.first(ord_map)
      {:b, "Bat"}
      iex> A.OrdMap.last(ord_map)
      {:c, "Cat"}
      iex> A.OrdMap.foldr(ord_map, [], fn {_key, value}, acc -> [value <> "man" | acc] end)
      ["Batman", "Antman", "Catman"]

  ## Access behaviour

  `A.OrdMap` implements the `Access` behaviour.

      iex> ord_map = A.OrdMap.new([a: "Ant", b: "Bat", c: "Cat"])
      iex> ord_map[:a]
      "Ant"
      iex> put_in(ord_map[:b], "Buffalo")
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> put_in(ord_map[:d], "Dinosaur")
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"})>
      iex> {"Cat", updated} = pop_in(ord_map[:c]); updated
      #A<ord(%{a: "Ant", b: "Bat"})>

  ## Convenience [`ord/1`](`A.ord/1`) and [`ord_size/1`](`A.ord_size/1`) macros

  The `A.OrdMap` module can be used without any macro.

  The `A.ord/1` macro does however provide some syntactic sugar to make
  it more convenient to work with ordered maps, namely:
  - construct new ordered maps without the clutter of a entry list
  - pattern match on key-values like regular maps
  - update some existing keys

  Examples:

      iex> import A
      iex> ord_map = ord(%{"一" => 1, "二" => 2, "三" => 3})
      #A<ord(%{"一" => 1, "二" => 2, "三" => 3})>
      iex> ord(%{"三" => three, "一" => one}) = ord_map
      iex> {one, three}
      {1, 3}
      iex> ord(%{ord_map | "二" => "NI!"})
      #A<ord(%{"一" => 1, "二" => "NI!", "三" => 3})>

  Note: pattern-matching on keys is not affected by insertion order.

  The `A.ord_size/1` macro can be used in guards:

      iex> import A
      iex> match?(v when ord_size(v) > 2, ord%{"一" => 1, "二" => 2, "三" => 3})
      true


  ## With `Jason`

      iex> A.OrdMap.new([{"un", 1}, {"deux", 2}, {"trois", 3}]) |> Jason.encode!()
      "{\"un\":1,\"deux\":2,\"trois\":3}"

  JSON encoding preserves the insertion order. Comparing with a regular map:

      iex> Map.new([{"un", 1}, {"deux", 2}, {"trois", 3}]) |> Jason.encode!()
      "{\"deux\":2,\"trois\":3,\"un\":1}"

  There is no way as of now to decode JSON using `A.OrdMap`.

  ## Key deletion and sparse maps

  Due to the underlying structures being used, efficient key deletion implies keeping around some
  "holes" to avoid rebuilding the whole structure.

  Such an ord map will be called **sparse**, while an ord map that never had a key deleted will be
  referred as **dense**.

  The implications of sparse structures are multiple:
  - unlike dense structures, they cannot be compared as erlang terms
    (using either `==/2`, `===/2` or the pin operator `^`)
  - `A.OrdMap.equal?/2` can safely compare both sparse and dense structures, but is slower for sparse
  - enumerating sparse structures is less efficient than dense ones

  Calling `A.OrdMap.new/1` on a sparse ord map will rebuild a new dense one from scratch (which can be expensive).

      iex> dense = A.OrdMap.new(a: "Ant", b: "Bat")
      #A<ord(%{a: "Ant", b: "Bat"})>
      iex> sparse = A.OrdMap.new(c: "Cat", a: "Ant", b: "Bat") |> A.OrdMap.delete(:c)
      #A<ord(%{a: "Ant", b: "Bat"}, sparse?: true)>
      iex> dense == sparse
      false
      iex> match?(^dense, sparse)
      false
      iex> A.OrdMap.equal?(dense, sparse)  # works with sparse maps, but less efficient
      true
      iex> new_dense = A.OrdMap.new(sparse)  # rebuild a dense map from a sparse one
      #A<ord(%{a: "Ant", b: "Bat"})>
      iex> new_dense === dense
      true

  In order to avoid having to worry about memory issues when adding and deleting keys successively,
  ord maps cannot be more than half sparse, and are periodically rebuilt as dense upon deletion.

      iex> sparse = A.OrdMap.new(c: "Cat", a: "Ant", b: "Bat") |> A.OrdMap.delete(:c)
      #A<ord(%{a: "Ant", b: "Bat"}, sparse?: true)>
      iex> A.OrdMap.delete(sparse, :a)
      #A<ord(%{b: "Bat"})>

  Note: Deleting the last key does not make a dense ord map sparse. This is not a bug,
  but an expected behavior due to how data is stored.

      iex> A.OrdMap.new([one: 1, two: 2, three: 3]) |> A.OrdMap.delete(:three)
      #A<ord(%{one: 1, two: 2})>

  The `dense?/1` and `sparse?/1` functions can be used to check if a `A.OrdMap` is dense or sparse.

  While this design puts some burden on the developer, the idea behind it is:
  - to keep it as convenient and performant as possible unless deletion is necessary
  - to be transparent about sparse structures and their limitation
  - instead of constantly rebuild new dense structures, let users decide the best timing to do it
  - still work fine with sparse structures, but in a degraded mode
  - protect users about potential memory leaks and performance issues

  ## Pattern-matching and opaque type

  An `A.OrdMap` is represented internally using the `%A.OrdMap{}` struct. This struct
  can be used whenever there's a need to pattern match on something being an `A.OrdMap`:
      iex> match?(%A.OrdMap{}, A.OrdMap.new())
      true

  Note, however, than `A.OrdMap` is an [opaque type](https://hexdocs.pm/elixir/typespecs.html#user-defined-types):
  its struct internal fields must not be accessed directly.

  As discussed in the previous section, [`ord/1`](`A.ord/1`) and [`ord_size/1`](`A.ord_size/1`) makes it
  possible to pattern match on keys as well as check the type and size.

  ## Memory overhead

  `A.OrdMap` takes roughly 2~3x more memory than a regular map depending on the type of data:

      iex> map_size = Map.new(1..100, fn i -> {i, i} end) |> :erts_debug.size()
      358
      iex> ord_map_size = A.OrdMap.new(1..100, fn i -> {i, i} end) |> :erts_debug.size()
      1112
      iex> ord_map_size / map_size
      3.106145251396648

  """

  @behaviour Access

  @type key :: term
  @type value :: term
  @typep index :: non_neg_integer
  @typep internals(key, value) :: %__MODULE__{
           __ord_map__: %{optional(key) => {index, value}},
           __ord_vector__: A.Vector.Raw.t({key, value}),
           __ord_next__: index
         }
  @type t(key, value) :: internals(key, value)
  @type t :: t(key, value)
  defstruct __ord_map__: %{}, __ord_vector__: A.Vector.Raw.empty(), __ord_next__: 0

  # TODO simplify when stop supporting Elixir 1.10
  defguardp is_dense(ord_map)
            when :erlang.map_get(:__ord_map__, ord_map) |> map_size() ===
                   :erlang.map_get(:__ord_next__, ord_map)

  @doc """
  Returns the number of keys in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.size(ord_map)
      3
      iex> A.OrdMap.size(A.OrdMap.new())
      0

  """
  @spec size(t) :: non_neg_integer
  def size(ord_map)

  def size(%__MODULE__{__ord_map__: map}) do
    map_size(map)
  end

  @doc """
  Returns all keys from `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.OrdMap.keys(ord_map)
      [:b, :c, :a]

  """
  @spec keys(t(k, value)) :: [k] when k: key
  def keys(ord_map)

  def keys(%__MODULE__{__ord_vector__: vector}) do
    A.Vector.Raw.foldr(vector, [], fn
      {key, _value}, acc -> [key | acc]
      nil, acc -> acc
    end)
  end

  @doc """
  Returns all values from `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.OrdMap.values(ord_map)
      ["Bat", "Cat", "Ant"]

  """
  @spec values(t(key, v)) :: [v] when v: value
  def values(ord_map)

  def values(%__MODULE__{__ord_vector__: vector}) do
    A.Vector.Raw.foldr(vector, [], fn
      {_key, value}, acc -> [value | acc]
      nil, acc -> acc
    end)
  end

  @doc """
  Returns all key-values pairs from `ord_map` as a list.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.OrdMap.to_list(ord_map)
      [b: "Bat", c: "Cat", a: "Ant"]

  """
  @spec to_list(t(k, v)) :: [{k, v}] when k: key, v: value
  def to_list(ord_map)

  def to_list(%__MODULE__{__ord_vector__: vector} = ord_map) when is_dense(ord_map) do
    A.Vector.Raw.to_list(vector)
  end

  def to_list(%__MODULE__{__ord_vector__: vector}) do
    A.Vector.Raw.sparse_to_list(vector)
  end

  @doc """
  Returns  all key-values pairs from `ord_map` as a vector.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.OrdMap.to_vector(ord_map)
      #A<vec([b: "Bat", c: "Cat", a: "Ant"])>

  """
  @spec to_vector(t(k, v)) :: A.Vector.t({k, v}) when k: key, v: value
  def to_vector(ord_map)

  def to_vector(%__MODULE__{__ord_vector__: vector} = ord_map) when is_dense(ord_map) do
    %A.Vector{__vector__: vector}
  end

  def to_vector(%__MODULE__{__ord_vector__: vector}) do
    A.Vector.Raw.sparse_to_list(vector) |> A.Vector.new()
  end

  @doc """
  Returns a new empty ordered map.

  ## Examples

      iex> A.OrdMap.new()
      #A<ord(%{})>

  """
  @spec new :: t
  def new() do
    %__MODULE__{}
  end

  @doc """
  Creates an ordered map from an `enumerable`.

  Preserves the original order of keys.
  Duplicated keys are removed; the latest one prevails.

  ## Examples

      iex> A.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      #A<ord(%{b: "Bat", a: "Ant", c: "Cat"})>
      iex> A.OrdMap.new(b: "Bat", a: "Ant", b: "Buffalo", a: "Antelope")
      #A<ord(%{b: "Buffalo", a: "Antelope"})>

  `new/1` will return dense ord maps untouched, but will rebuild sparse ord maps from scratch.
  This can be used to build a dense ord map from from a sparse one.
  See the [section about sparse structures](#module-key-deletion-and-sparse-maps) for more information.

      iex> sparse = A.OrdMap.new(c: "Cat", a: "Ant", b: "Bat") |> A.OrdMap.delete(:c)
      #A<ord(%{a: "Ant", b: "Bat"}, sparse?: true)>
      iex> A.OrdMap.new(sparse)
      #A<ord(%{a: "Ant", b: "Bat"})>

  """
  @spec new(Enumerable.t()) :: t(key, value)
  def new(%__MODULE__{} = ord_map) when is_dense(ord_map), do: ord_map

  def new(enumerable) do
    # TODO add from_vector
    enumerable
    |> A.FastEnum.to_list()
    |> from_list()
  end

  @doc """
  Creates an ordered map from an `enumerable` via the given `transform` function.

  Preserves the original order of keys.
  Duplicated keys are removed; the latest one prevails.

  ## Examples

      iex> A.OrdMap.new([:a, :b], fn x -> {x, x} end)
      #A<ord(%{a: :a, b: :b})>

  """
  @spec new(Enumerable.t(), (term -> {k, v})) :: t(k, v) when k: key, v: value
  def new(enumerable, fun) do
    # TODO optimize
    enumerable
    |> Enum.map(fun)
    |> new()
  end

  @doc """
  Returns whether the given `key` exists in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.has_key?(ord_map, :a)
      true
      iex> A.OrdMap.has_key?(ord_map, :d)
      false

  """
  @spec has_key?(t(k, value), k) :: boolean when k: key
  def has_key?(ord_map, key)

  def has_key?(%__MODULE__{__ord_map__: map}, key) do
    Map.has_key?(map, key)
  end

  @doc ~S"""
  Fetches the value for a specific `key` and returns it in a ok-entry.
  If the key does not exist, returns :error.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "A", b: "B", c: "C")
      iex> A.OrdMap.fetch(ord_map, :c)
      {:ok, "C"}
      iex> A.OrdMap.fetch(ord_map, :z)
      :error

  """
  @impl Access
  @spec fetch(t(k, v), k) :: {:ok, v} | :error when k: key, v: value
  def fetch(ord_map, key)

  def fetch(%__MODULE__{__ord_map__: map}, key) do
    case map do
      %{^key => {_index, value}} ->
        {:ok, value}

      _ ->
        :error
    end
  end

  @doc ~S"""
  Fetches the value for a specific `key` in the given `ord_map`,
  erroring out if `ord_map` doesn't contain `key`.

  If `ord_map` doesn't contain `key`, a `KeyError` exception is raised.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "A", b: "B", c: "C")
      iex> A.OrdMap.fetch!(ord_map, :c)
      "C"
      iex> A.OrdMap.fetch!(ord_map, :z)
      ** (KeyError) key :z not found in: #A<ord(%{a: "A", b: "B", c: "C"})>

  """
  @spec fetch!(t(k, v), k) :: v when k: key, v: value
  def fetch!(%__MODULE__{__ord_map__: map} = ord_map, key) do
    case map do
      %{^key => {_index, value}} ->
        value

      _ ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc """
  Puts the given `value` under `key` unless the entry `key`
  already exists in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat")
      iex> A.OrdMap.put_new(ord_map, :a, "Ant")
      #A<ord(%{b: "Bat", c: "Cat", a: "Ant"})>
      iex> A.OrdMap.put_new(ord_map, :b, "Buffalo")
      #A<ord(%{b: "Bat", c: "Cat"})>

  """
  @spec put_new(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def put_new(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key,
        value
      ) do
    case map do
      %{^key => _value} ->
        ord_map

      _ ->
        do_add_new(map, vector, next_index, key, value)
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.replace(ord_map, :b, "Buffalo")
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> A.OrdMap.replace(ord_map, :d, "Dinosaur")
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>

  """
  @spec replace(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key,
        value
      ) do
    case map do
      %{^key => {index, _value}} ->
        do_add_existing(map, vector, index, key, value, next_index)

      _ ->
        ord_map
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  If `key` is not present in `ord_map`, a `KeyError` exception is raised.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.replace!(ord_map, :b, "Buffalo")
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> A.OrdMap.replace!(ord_map, :d, "Dinosaur")
      ** (KeyError) key :d not found in: #A<ord(%{a: \"Ant\", b: \"Bat\", c: \"Cat\"})>

  """
  @spec replace!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace!(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key,
        value
      ) do
    case map do
      %{^key => {index, _value}} ->
        do_add_existing(map, vector, index, key, value, next_index)

      _ ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc """
  Evaluates `fun` and puts the result under `key`
  in `ord_map` unless `key` is already present.

  This function is useful in case you want to compute the value to put under
  `key` only if `key` is not already present, as for example, when the value is expensive to
  calculate or generally difficult to setup and teardown again.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat")
      iex> expensive_fun = fn -> "Ant" end
      iex> A.OrdMap.put_new_lazy(ord_map, :a, expensive_fun)
      #A<ord(%{b: "Bat", c: "Cat", a: "Ant"})>
      iex> A.OrdMap.put_new_lazy(ord_map, :b, expensive_fun)
      #A<ord(%{b: "Bat", c: "Cat"})>

  """
  @spec put_new_lazy(t(k, v), k, (() -> v)) :: t(k, v) when k: key, v: value
  def put_new_lazy(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key,
        fun
      )
      when is_function(fun, 0) do
    if has_key?(ord_map, key) do
      ord_map
    else
      do_add_new(map, vector, next_index, key, fun.())
    end
  end

  @doc """
  Returns a new ordered map with all the key-value pairs in `ord_map` where the key
  is in `keys`.

  If `keys` contains keys that are not in `ord_map`, they're simply ignored.
  Respects the order of the `keys` list.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.take(ord_map, [:c, :e, :a])
      #A<ord(%{c: "Cat", a: "Ant"})>

  """
  @spec get(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def take(ord_map, keys)

  def take(%__MODULE__{__ord_map__: map}, keys) when is_list(keys) do
    do_take(map, keys, [], %{}, 0)
  end

  defp do_take(_map, _keys = [], kvs, map_acc, index) do
    vector = kvs |> :lists.reverse() |> A.Vector.Raw.from_list()
    %__MODULE__{__ord_map__: map_acc, __ord_vector__: vector, __ord_next__: index}
  end

  defp do_take(map, [key | keys], kvs, map_acc, index) do
    case map do
      %{^key => {_index, value}} ->
        new_kvs = [{key, value} | kvs]
        new_map_acc = Map.put(map_acc, key, {index, value})
        do_take(map, keys, new_kvs, new_map_acc, index + 1)

      _ ->
        do_take(map, keys, kvs, map_acc, index)
    end
  end

  @doc """
  Gets the value for a specific `key` in `ord_map`.

  If `key` is present in `ord_map` then its value `value` is
  returned. Otherwise, `default` is returned.

  If `default` is not provided, `nil` is used.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.get(ord_map, :a)
      "Ant"
      iex> A.OrdMap.get(ord_map, :z)
      nil
      iex> A.OrdMap.get(ord_map, :z, "Zebra")
      "Zebra"

  """
  @spec get(t(k, v), k, v) :: v | nil when k: key, v: value
  def get(ord_map, key, default \\ nil)

  def get(%__MODULE__{__ord_map__: map}, key, default) do
    case map do
      %{^key => {_index, value}} ->
        value

      _ ->
        default
    end
  end

  @doc """
  Gets the value for a specific `key` in `ord_map`.

  If `key` is present in `ord_map` then its value `value` is
  returned. Otherwise, `fun` is evaluated and its result is returned.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> expensive_fun = fn -> "Zebra" end
      iex> A.OrdMap.get_lazy(ord_map, :a, expensive_fun)
      "Ant"
      iex> A.OrdMap.get_lazy(ord_map, :z, expensive_fun)
      "Zebra"

  """
  @spec get_lazy(t(k, v), k, v) :: v | nil when k: key, v: value
  def get_lazy(ord_map, key, fun)

  def get_lazy(%__MODULE__{__ord_map__: map}, key, fun) when is_function(fun, 0) do
    case map do
      %{^key => {_index, value}} ->
        value

      _ ->
        fun.()
    end
  end

  @doc """
  Puts the given `value` under `key` in `ord_map`.

  If the `key` does exist, it overwrites the existing value without
  changing its current location.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.put(ord_map, :b, "Buffalo")
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> A.OrdMap.put(ord_map, :d, "Dinosaur")
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"})>

  """
  @spec put(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def put(ord_map, key, value)

  def put(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index},
        key,
        value
      ) do
    case map do
      %{^key => {index, _value}} ->
        do_add_existing(map, vector, index, key, value, next_index)

      _ ->
        do_add_new(map, vector, next_index, key, value)
    end
  end

  @doc """
  Deletes the entry in `ord_map` for a specific `key`.

  If the `key` does not exist, returns `ord_map` unchanged.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.delete(ord_map, :b)
      #A<ord(%{a: "Ant", c: "Cat"}, sparse?: true)>
      iex> A.OrdMap.delete(ord_map, :z)
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>

  """
  @spec delete(t(k, v), k) :: t(k, v) when k: key, v: value
  def delete(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key
      ) do
    case :maps.take(key, map) do
      {{index, _value}, new_map} ->
        do_delete_existing(new_map, vector, index, next_index)

      :error ->
        ord_map
    end
  end

  @doc """
  Merges a map or an ordered map into an `ord_map`.

  All keys in `map_or_ord_map` will be added to `ord_map`, overriding any existing one
  (i.e., the keys in `map_or_ord_map` "have precedence" over the ones in `ord_map`).

  ## Examples

      iex> A.OrdMap.merge(A.OrdMap.new(%{a: 1, b: 2}), A.OrdMap.new(%{a: 3, d: 4}))
      #A<ord(%{a: 3, b: 2, d: 4})>
      iex> A.OrdMap.merge(A.OrdMap.new(%{a: 1, b: 2}), %{a: 3, d: 4})
      #A<ord(%{a: 3, b: 2, d: 4})>

  """
  @spec merge(t(k, v), t(k, v) | %{optional(k) => v}) :: t(k, v) when k: key, v: value
  def merge(ord_map, map_or_ord_map)

  def merge(%__MODULE__{} = ord_map1, %__MODULE__{} = ord_map2) do
    do_merge(ord_map1, to_list(ord_map2))
  end

  def merge(%__MODULE__{}, %_{}) do
    raise ArgumentError, "Cannot merge arbitrary structs"
  end

  def merge(%__MODULE__{} = ord_map1, %{} = map2) do
    do_merge(ord_map1, Map.to_list(map2))
  end

  defp do_merge(
         %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index},
         new_kvs
       ) do
    {new_map, reversed_kvs, new_next, duplicates} =
      do_add_optimistic(new_kvs, map, [], next_index)

    new_vector =
      vector
      |> A.Vector.Raw.concat(:lists.reverse(reversed_kvs))
      |> do_fix_vector_duplicates(map, duplicates)

    %__MODULE__{__ord_map__: new_map, __ord_vector__: new_vector, __ord_next__: new_next}
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.update(ord_map, :b, "N/A", &String.upcase/1)
      #A<ord(%{a: "Ant", b: "BAT", c: "Cat"})>
      iex> A.OrdMap.update(ord_map, :z, "N/A", &String.upcase/1)
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat", z: "N/A"})>

  """
  @spec update(t(k, v), k, v, (k -> v)) :: t(k, v) when k: key, v: value
  def update(ord_map, key, default, fun)

  def update(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index},
        key,
        default,
        fun
      )
      when is_function(fun, 1) do
    case map do
      %{^key => {index, value}} ->
        do_add_existing(map, vector, index, key, fun.(value), next_index)

      _ ->
        do_add_new(map, vector, next_index, key, default)
    end
  end

  @doc ~S"""
  Returns the value for `key` and the updated ordered map without `key`.

  If `key` is present in the ordered map with a value `value`,
  `{value, new_ord_map}` is returned.
  If `key` is not present in the ordered map, `{default, ord_map}` is returned.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"Bat", updated} = A.OrdMap.pop(ord_map, :b)
      iex> updated
      #A<ord(%{a: "Ant", c: "Cat"}, sparse?: true)>
      iex> {nil, updated} = A.OrdMap.pop(ord_map, :z)
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
      iex> {"Z", updated} = A.OrdMap.pop(ord_map, :z, "Z")
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
  """
  @impl Access
  @spec pop(t(k, v), k, v) :: {v, t(k, v)} when k: key, v: value
  def pop(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key,
        default \\ nil
      ) do
    case :maps.take(key, map) do
      {{index, value}, new_map} ->
        {value, do_delete_existing(new_map, vector, index, next_index)}

      :error ->
        {default, ord_map}
    end
  end

  @doc ~S"""
  Returns the value for `key` and the updated ordered map without `key`.

  Behaves the same as `pop/3` but raises if `key` is not present in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"Bat", updated} = A.OrdMap.pop!(ord_map, :b)
      iex> updated
      #A<ord(%{a: "Ant", c: "Cat"}, sparse?: true)>
      iex> A.OrdMap.pop!(ord_map, :z)
      ** (KeyError) key :z not found in: #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
  """
  @spec pop!(t(k, v), k) :: {v, t(k, v)} when k: key, v: value
  def pop!(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key
      ) do
    case :maps.take(key, map) do
      {{index, value}, new_map} ->
        {value, do_delete_existing(new_map, vector, index, next_index)}

      :error ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc """
  Lazily returns and removes the value associated with `key` in `ord_map`.

  If `key` is present in `ord_map`, it returns `{value, new_map}` where `value` is the value of
  the key and `new_map` is the result of removing `key` from `ord_map`. If `key`
  is not present in `ord_map`, `{fun_result, ord_map}` is returned, where `fun_result`
  is the result of applying `fun`.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      iex> expensive_fun = fn -> "Zebra" end
      iex> {"Ant", updated} = A.OrdMap.pop_lazy(ord_map, :a, expensive_fun)
      iex> updated
      #A<ord(%{b: "Bat", c: "Cat"}, sparse?: true)>
      iex> {"Zebra", not_updated} = A.OrdMap.pop_lazy(ord_map, :z, expensive_fun)
      iex> not_updated
      #A<ord(%{b: "Bat", a: "Ant", c: "Cat"})>

  """
  @spec pop_lazy(t(k, v), k, (() -> v)) :: {v, t(k, v)} when k: key, v: value
  def pop_lazy(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key,
        fun
      )
      when is_function(fun, 0) do
    case :maps.take(key, map) do
      {{index, value}, new_map} ->
        {value, do_delete_existing(new_map, vector, index, next_index)}

      :error ->
        {fun.(), ord_map}
    end
  end

  @doc """
  Drops the given `keys` from `ord_map`.

  If `keys` contains keys that are not in `ord_map`, they're simply ignored.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.drop(ord_map, [:b, :d])
      #A<ord(%{a: "Ant", c: "Cat"}, sparse?: true)>

  """
  @spec drop(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def drop(%__MODULE__{} = ord_map, keys) when is_list(keys) do
    # TODO optimize
    Enum.reduce(keys, ord_map, fn key, acc ->
      delete(acc, key)
    end)
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  If `key` is not present in `ord_map`, a `KeyError` exception is raised.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.update!(ord_map, :b,  &String.upcase/1)
      #A<ord(%{a: "Ant", b: "BAT", c: "Cat"})>
      iex> A.OrdMap.update!(ord_map, :d, &String.upcase/1)
      ** (KeyError) key :d not found in: #A<ord(%{a: \"Ant\", b: \"Bat\", c: \"Cat\"})>

  """
  @spec update!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def update!(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key,
        fun
      )
      when is_function(fun, 1) do
    case map do
      %{^key => {index, value}} ->
        do_add_existing(map, vector, index, key, fun.(value), next_index)

      _ ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc ~S"""
  Gets the value from `key` and updates it, all in one pass.

  Mirrors `Map.get_and_update/3`, see its documentation.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"bat", updated} = A.OrdMap.get_and_update(ord_map, :b, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Buffalo"}
      ...> end)
      iex> updated
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> {nil, updated} = A.OrdMap.get_and_update(ord_map, :z, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Zebra"}
      ...> end)
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat", z: "Zebra"})>
      iex> {"Bat", updated} = A.OrdMap.get_and_update(ord_map, :b, fn _ -> :pop end)
      iex> updated
      #A<ord(%{a: "Ant", c: "Cat"}, sparse?: true)>
      iex> {nil, updated} = A.OrdMap.get_and_update(ord_map, :z, fn _ -> :pop end)
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
  """
  @impl Access
  @spec get_and_update(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update(%__MODULE__{} = ord_map, key, fun) when is_function(fun, 1) do
    current = get(ord_map, key)

    do_get_and_update(ord_map, key, fun, current)
  end

  @doc ~S"""
  Gets the value from `key` and updates it, all in one pass.

  Mirrors `Map.get_and_update!/3`, see its documentation.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"bat", updated} = A.OrdMap.get_and_update!(ord_map, :b, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Buffalo"}
      ...> end)
      iex> updated
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> A.OrdMap.get_and_update!(ord_map, :z, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Zebra"}
      ...> end)
      ** (KeyError) key :z not found in: #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
  """
  @spec get_and_update!(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update!(%__MODULE__{} = ord_map, key, fun) when is_function(fun, 1) do
    current = fetch!(ord_map, key)

    do_get_and_update(ord_map, key, fun, current)
  end

  defp do_get_and_update(ord_map, key, fun, current) do
    case fun.(current) do
      {get, update} ->
        {get, put(ord_map, key, update)}

      :pop ->
        {current, delete(ord_map, key)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  @doc """
  Converts a `struct` to an ordered map.

  It accepts the struct module or a struct itself and
  simply removes the `__struct__` field from the given struct
  or from a new struct generated from the given module.

  ## Example

      defmodule User do
        defstruct [:name, :age]
      end

      A.OrdMap.from_struct(User)
      #A<ord(%{age: nil, name: nil})>

      A.OrdMap.from_struct(%User{name: "john", age: 44})
      #A<ord(%{age: 44, name: "john"})>

  """
  @spec from_struct(atom | struct) :: t
  def from_struct(struct) do
    struct |> Map.from_struct() |> new()
  end

  @doc """
  Checks if two ordered maps are equal, meaning they have the same key-value pairs
  in the same order.

  ## Examples

      iex> A.OrdMap.equal?(A.OrdMap.new(a: 1, b: 2), A.OrdMap.new(a: 1, b: 2))
      true
      iex> A.OrdMap.equal?(A.OrdMap.new(a: 1, b: 2), A.OrdMap.new(b: 2, a: 1))
      false
      iex> A.OrdMap.equal?(A.OrdMap.new(a: 1, b: 2), A.OrdMap.new(a: 3, b: 2))
      false

  """
  @spec equal?(t, t) :: boolean
  def equal?(ord_map1, ord_map2)

  def equal?(%A.OrdMap{__ord_map__: map1} = ord_map1, %A.OrdMap{__ord_map__: map2} = ord_map2) do
    case {map_size(map1), map_size(map2)} do
      {size, size} ->
        case {ord_map1.__ord_next__, ord_map2.__ord_next__} do
          {^size, ^size} ->
            # both are dense, maps can be compared safely
            map1 === map2

          {_, _} ->
            # one of them is sparse, inefficient comparison
            A.Vector.Raw.sparse_to_list(ord_map1.__ord_vector__) ===
              A.Vector.Raw.sparse_to_list(ord_map2.__ord_vector__)
        end

      {_, _} ->
        # size mismatch: cannot be equal
        false
    end
  end

  # Extra specific functions

  @doc """
  Finds the fist `{key, value}` pair in `ord_map`.

  Returns a `{key, value}` entry if `ord_map` is non-empty, or `nil` else.

  ## Examples

      iex> A.OrdMap.new([b: "B", d: "D", a: "A", c: "C"]) |> A.OrdMap.first()
      {:b, "B"}
      iex> A.OrdMap.new([]) |> A.OrdMap.first()
      nil
      iex> A.OrdMap.new([]) |> A.OrdMap.first(:error)
      :error

  """
  @spec first(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def first(ord_map, default \\ nil)

  def first(%A.OrdMap{__ord_vector__: vector} = ord_map, default) when is_dense(ord_map) do
    A.Vector.Raw.first(vector, default)
  end

  def first(%A.OrdMap{__ord_vector__: vector}, default) do
    case A.Vector.Raw.find(vector, fn value -> value end) do
      {:ok, found} -> found
      _ -> default
    end
  end

  @doc """
  Finds the last `{key, value}` pair in `ord_map`.

  Returns a `{key, value}` entry if `ord_map` is non-empty, or `nil` else.
  Can be accessed efficiently due to the underlying vector.

  ## Examples

      iex> A.OrdMap.new([b: "B", d: "D", a: "A", c: "C"]) |> A.OrdMap.last()
      {:c, "C"}
      iex> A.OrdMap.new([]) |> A.OrdMap.last()
      nil
      iex> A.OrdMap.new([]) |> A.OrdMap.last(:error)
      :error

  """
  @spec last(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def last(ord_map, default \\ nil)

  def last(%A.OrdMap{__ord_vector__: vector} = ord_map, default) when is_dense(ord_map) do
    A.Vector.Raw.last(vector, default)
  end

  def last(%A.OrdMap{__ord_vector__: vector}, default) do
    try do
      A.Vector.Raw.foldr(vector, nil, fn value, _acc ->
        if value, do: throw(value)
      end)

      default
    catch
      value ->
        value
    end
  end

  @doc """
  Folds (reduces) the given `ord_map` from the left with the function `fun`.
  Requires an accumulator `acc`.

  ## Examples

      iex> ord_map = A.OrdMap.new([b: "Bat", c: "Cat", a: "Ant"])
      iex> A.OrdMap.foldl(ord_map, "", fn {_key, value}, acc -> value <> acc end)
      "AntCatBat"
      iex> A.OrdMap.foldl(ord_map, [], fn {key, value}, acc -> [{key, value <> "man"} | acc] end)
      [a: "Antman", c: "Catman", b: "Batman"]

  """
  def foldl(ord_map, acc, fun)

  def foldl(%__MODULE__{__ord_vector__: vector} = ord_map, acc, fun) when is_function(fun, 2) do
    case ord_map do
      dense when is_dense(dense) -> A.Vector.Raw.foldl(vector, acc, fun)
      _sparse -> A.Vector.Raw.sparse_to_list(vector) |> List.foldl(acc, fun)
    end
  end

  @doc """
  Folds (reduces) the given `ord_map` from the right with the function `fun`.
  Requires an accumulator `acc`.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> ord_map = A.OrdMap.new([b: "Bat", c: "Cat", a: "Ant"])
      iex> A.OrdMap.foldr(ord_map, "", fn {_key, value}, acc -> value <> acc end)
      "BatCatAnt"
      iex> A.OrdMap.foldr(ord_map, [], fn {key, value}, acc -> [{key, value <> "man"} | acc] end)
      [b: "Batman", c: "Catman", a: "Antman"]

  """
  def foldr(ord_map, acc, fun)

  def foldr(%__MODULE__{__ord_vector__: vector} = ord_map, acc, fun) when is_function(fun, 2) do
    case ord_map do
      dense when is_dense(dense) -> A.Vector.Raw.foldr(vector, acc, fun)
      _sparse -> A.Vector.Raw.sparse_to_list(vector) |> List.foldr(acc, fun)
    end
  end

  @doc """
  Returns `true` if `ord_map` is dense; otherwise returns `false`.

  See the [section about sparse structures](#module-key-deletion-and-sparse-maps) for more information.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
      iex> A.OrdMap.dense?(ord_map)
      true
      iex> sparse = A.OrdMap.delete(ord_map, :b)
      #A<ord(%{a: "Ant", c: "Cat"}, sparse?: true)>
      iex> A.OrdMap.dense?(sparse)
      false

  """
  def dense?(%__MODULE__{} = ord_map) do
    is_dense(ord_map)
  end

  @doc """
  Returns `true` if `ord_map` is sparse; otherwise returns `false`.

  See the [section about sparse structures](#module-key-deletion-and-sparse-maps) for more information.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
      iex> A.OrdMap.sparse?(ord_map)
      false
      iex> sparse = A.OrdMap.delete(ord_map, :b)
      #A<ord(%{a: "Ant", c: "Cat"}, sparse?: true)>
      iex> A.OrdMap.sparse?(sparse)
      true

  """
  def sparse?(%__MODULE__{} = ord_map) do
    !is_dense(ord_map)
  end

  # Exposed "private" functions

  @doc false
  def replace_many!(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index} = ord_map,
        key_values
      ) do
    case do_replace_many(key_values, map, vector) do
      {:error, key} ->
        raise KeyError, key: key, term: ord_map

      {:ok, map, vector} ->
        %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index}
    end
  end

  # Private functions

  defp do_add_new(map, vector, index, key, value) do
    new_vector = A.Vector.Raw.append(vector, {key, value})
    new_map = Map.put(map, key, {index, value})

    %__MODULE__{__ord_map__: new_map, __ord_vector__: new_vector, __ord_next__: index + 1}
  end

  defp do_add_existing(map, vector, index, key, value, next_index) do
    new_vector = A.Vector.Raw.replace_positive!(vector, index, {key, value})
    new_map = Map.put(map, key, {index, value})

    %__MODULE__{__ord_map__: new_map, __ord_vector__: new_vector, __ord_next__: next_index}
  end

  defp do_delete_existing(new_map, _vector, _index, _next_index) when new_map === %{} do
    # always return the same empty ord map, and reset the index to avoid considering it as sparse
    %__MODULE__{}
  end

  defp do_delete_existing(new_map, vector, index, next_index) when index == next_index - 1 do
    {_lat, new_vector} = A.Vector.Raw.pop_last(vector)
    %__MODULE__{__ord_map__: new_map, __ord_vector__: new_vector, __ord_next__: index}
  end

  defp do_delete_existing(new_map, vector, index, next_index) do
    new_vector = A.Vector.Raw.replace_positive!(vector, index, nil)
    periodic_rebuild(new_map, new_vector, next_index)
  end

  defp do_fix_vector_duplicates(vector, _map, _duplicates = nil) do
    vector
  end

  defp do_fix_vector_duplicates(vector, map, duplicates) do
    Enum.reduce(duplicates, vector, fn {key, value}, acc ->
      %{^key => {index, _value}} = map
      A.Vector.Raw.replace_positive!(acc, index, {key, value})
    end)
  end

  defp do_replace_many([], map, vector) do
    {:ok, map, vector}
  end

  defp do_replace_many([{key, value} | rest], map, vector) do
    case map do
      %{^key => {index, _value}} ->
        new_map = Map.replace!(map, key, {index, value})
        new_vector = A.Vector.Raw.replace_positive!(vector, index, {key, value})
        do_replace_many(rest, new_map, new_vector)

      _ ->
        {:error, key}
    end
  end

  defp from_list([]) do
    new()
  end

  defp from_list(list) do
    {map, key_values, index} =
      case do_add_optimistic(list, %{}, [], 0) do
        {map, reversed_kvs, index, nil} ->
          {map, :lists.reverse(reversed_kvs), index}

        {map, reversed_kvs, index, duplicates} ->
          {map, do_reverse_and_update_duplicates(reversed_kvs, duplicates, []), index}
      end

    vector = A.Vector.Raw.from_list(key_values)
    %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: index}
  end

  @compile {:inline, do_add_optimistic: 4}

  defp do_add_optimistic([], map, key_values, next_index) do
    {map, key_values, next_index, nil}
  end

  defp do_add_optimistic([{key, value} | rest], map, key_values, next_index) do
    case map do
      %{^key => {index, _value}} ->
        duplicates = %{key => value}
        new_map = Map.put(map, key, {index, value})
        do_add_with_duplicates(rest, new_map, key_values, duplicates, next_index)

      _ ->
        new_map = Map.put(map, key, {next_index, value})
        new_kvs = [{key, value} | key_values]
        do_add_optimistic(rest, new_map, new_kvs, next_index + 1)
    end
  end

  defp do_add_with_duplicates([], map, key_values, duplicates, next_index) do
    {map, key_values, next_index, duplicates}
  end

  defp do_add_with_duplicates([{key, value} | rest], map, key_values, duplicates, next_index) do
    case map do
      %{^key => {index, _value}} ->
        new_duplicates = Map.put(duplicates, key, value)
        new_map = Map.put(map, key, {index, value})
        do_add_with_duplicates(rest, new_map, key_values, new_duplicates, next_index)

      _ ->
        new_map = Map.put(map, key, {next_index, value})
        new_kvs = [{key, value} | key_values]
        do_add_with_duplicates(rest, new_map, new_kvs, duplicates, next_index + 1)
    end
  end

  defp do_reverse_and_update_duplicates([], _duplicates, acc), do: acc

  defp do_reverse_and_update_duplicates([{key, value} | rest], duplicates, acc) do
    value =
      case duplicates do
        %{^key => new_value} -> new_value
        _ -> value
      end

    do_reverse_and_update_duplicates(rest, duplicates, [{key, value} | acc])
  end

  defp periodic_rebuild(map, vector, next_index) when next_index >= 2 * map_size(map) do
    vector
    |> A.Vector.Raw.sparse_to_list()
    |> from_list()
  end

  defp periodic_rebuild(map, vector, next_index) do
    %__MODULE__{__ord_map__: map, __ord_vector__: vector, __ord_next__: next_index}
  end

  defimpl Enumerable do
    def count(ord_map) do
      {:ok, A.OrdMap.size(ord_map)}
    end

    def member?(ord_map, key_value) do
      with {key, value} <- key_value,
           {:ok, ^value} <- A.OrdMap.fetch(ord_map, key) do
        {:ok, true}
      else
        _ -> {:ok, false}
      end
    end

    def slice(ord_map) do
      ord_map
      |> A.OrdMap.to_vector()
      |> Enumerable.slice()
    end

    def reduce(ord_map, acc, fun) do
      ord_map
      |> A.OrdMap.to_list()
      |> Enumerable.List.reduce(acc, fun)
    end
  end

  defimpl Collectable do
    def into(map) do
      fun = fn
        map_acc, {:cont, {key, value}} ->
          A.OrdMap.put(map_acc, key, value)

        map_acc, :done ->
          map_acc

        _map_acc, :halt ->
          :ok
      end

      {map, fun}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(ord_map, opts) do
      open = color("#A<ord(%{", :map, opts)
      sep = color(",", :map, opts)

      close = color(close_mark(ord_map), :map, opts)

      as_list = A.OrdMap.to_list(ord_map)

      container_doc(open, as_list, close, opts, traverse_fun(as_list, opts),
        separator: sep,
        break: :strict
      )
    end

    defp traverse_fun(list, opts) do
      if Inspect.List.keyword?(list) do
        &Inspect.List.keyword/2
      else
        sep = color(" => ", :map, opts)
        &to_map(&1, &2, sep)
      end
    end

    defp to_map({key, value}, opts, sep) do
      concat(concat(to_doc(key, opts), sep), to_doc(value, opts))
    end

    defp close_mark(ord_map) do
      if A.OrdMap.sparse?(ord_map) do
        "}, sparse?: true)>"
      else
        "})>"
      end
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(map, opts) do
        map |> A.OrdMap.to_list() |> Jason.Encode.keyword(opts)
      end
    end
  end
end

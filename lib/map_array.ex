defmodule MapArray do
  @moduledoc """
  Array data structure implemented as a map.

  Map arrays can be created from lists:

      iex> list = [0, 1, 2]
      iex> MapArray.from_list(list)
      #MapArray<[0, 1, 2]>

  Map arrays values can be retrieved with indices - integers in the form of atom, integer, or string:

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> map_array[0]
      0
      iex> map_array["1"]
      1
      iex> map_array[:"2"]
      2

  Map arrays values can be retrieved with negative indices:

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> map_array[-1]
      2

  """

  @behaviour Access

  @opaque t :: %__MODULE__{}
  @type index :: integer | atom | String.t
  @type value :: any

  defstruct [
    length: 0,
    array: %{}
  ]

  # Formats `index` to handle negative indices by using a `shift` value.
  @spec format_index(integer, integer) :: integer
  defp format_index(index, shift) do
    if index < 0 do
      index + shift
    else
      index
    end
  end

  # Converts `index` to a string. Adds `shift` to a negative index.
  #
  # Returns `{:ok, string}` if successful, else, `:error`.
  @spec to_binary_index(index, integer) :: {:ok, String.t} | :error
  defp to_binary_index(index, shift) do
    handle_binary_index = fn (binary_index) ->
      case Integer.parse(binary_index) do
        {integer_index, ""} ->
          formatted_integer_index = format_index(integer_index, shift)
          {:ok, Integer.to_string(formatted_integer_index)}

        _error ->
          :error
      end
    end

    cond do
      is_integer(index) ->
        index |> Integer.to_string() |> handle_binary_index.()

      is_atom(index) ->
        index |> Atom.to_string() |> handle_binary_index.()

      is_binary(index) ->
        index |> handle_binary_index.()
    end
  end

  # Converts `index` to a string. Adds `shift` to a negative index. Raises error if cannot convert.
  @spec to_binary_index!(index, integer) :: String.t
  defp to_binary_index!(index, shift \\ 0) do
    case to_binary_index(index, shift) do
      {:ok, binary_index} ->
        binary_index

      _error ->
        raise("cannot cast to integer")
    end
  end

  @doc """
  Fetches the value for a specific `index` in the given `map_array`.

  If `map_array` contains `index`, then the value is returned as `{:ok, value}`, else `:error` is returned.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> MapArray.fetch(map_array, 1)
      {:ok, 1}

  """
  @spec fetch(t, index) :: {:ok, value} | :error
  def fetch(%__MODULE__{length: length, array: array}, index) do
    with {:ok, binary_index} <- to_binary_index(index, length),
         true <- Map.has_key?(array, binary_index)
    do
      {:ok, array[binary_index]}
    else
      _error ->
        :error
    end
  end

  @doc """
  Fetches the value for a specific `index` in the given `map_array`. Raises error if `map_array` doesn't contain `index`.

  If `map_array` contains `index`, then the value is returned, else an exception is raised.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> MapArray.fetch!(map_array, 1)
      1

  """
  @spec fetch!(t, index) :: value
  def fetch!(%__MODULE__{} = map_array, index) do
    _binary_index = to_binary_index!(index)

    case fetch(map_array, index) do
      {:ok, value} ->
        value

      _error ->
        raise("invalid index")
    end
  end

  @doc """
  Gets the value from `index` and updates it, all in one pass.

  `function` is called with the current value under `index` in `map_array` (or `nil` if `index` is not present in
  `map_array`) and must return a two-element tuple: the current value (the retrieved value, which can be operated on
  before being returned) and the new value to be stored under `index` in the resulting new map. New value will not be
  stored if `index` is not present in `map_array`. `function` may also return `:pop`, which means the current value shall
  be removed from `map_array` and returned.

  The returned value is a two-element tuple with the current value returned by `function` and a new map array with the
  updated value under `index`.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> {1, map_array} = MapArray.get_and_update(map_array, 1, &({&1, &1 * 10}))
      iex> map_array
      #MapArray<[0, 10, 2]>

  """
  @spec get_and_update(t, index, (value | nil -> {current_value, new_value :: value} | :pop)) ::
          {current_value, new_map_array :: t}
        when current_value: value
  def get_and_update(%__MODULE__{length: length, array: array} = map_array, index, function) do
    {valid_index?, value} =
      case fetch(map_array, index) do
        {:ok, value} ->
          {true, value}

        _error ->
          {false, nil}
      end

    if valid_index? do
      case function.(value) do
        {current_value, new_value} ->
          binary_index = to_binary_index!(index, length)
          new_array = Map.put(array, binary_index, new_value)
          new_map_array = %{map_array | array: new_array}
          {current_value, new_map_array}

        :pop ->
          pop(map_array, index)
      end
    else
      case function.(value) do
        {current_value, _new_value} ->
          {current_value, map_array}

        :pop ->
          {value, map_array}
      end
    end
  end

  @doc """
  Gets the value from `index` and updates it, all in one pass. Raises error if there is no `index`.

  Behaves exactly like `get_and_update/3`, but raises an exception if `index` is not present in `map_array`.
  """
  @spec get_and_update!(t, index, (value | nil -> {current_value, new_value :: value} | :pop)) ::
          {current_value, new_map_array :: t}
        when current_value: value
  def get_and_update!(%__MODULE__{length: length, array: array} = map_array, index, function) do
    value = fetch!(map_array, index)

    case function.(value) do
      {current_value, new_value} ->
        binary_index = to_binary_index!(index, length)
        new_array = Map.put(array, binary_index, new_value)
        new_map_array = %{map_array | array: new_array}
        {current_value, new_map_array}

      :pop ->
        pop(map_array, index)
    end
  end

  @doc """
  Removes the value associated with `index` in `map_array` and returns the value and the updated map array.

  If `index` is present in `map_array`, it returns `{value, updated_map_array}` where `value` is the value of the key and
  `updated_map_array` is the result of removing `index` from `map_array`. If `index` is not present in `map_array`,
  `{nil, map_array}` is returned.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> {1, map_array} = MapArray.pop(map_array, 1)
      iex> map_array
      #MapArray<[0, 2]>

  """
  @spec pop(t, index) :: {value, updated_map_array :: t}
  def pop(%__MODULE__{length: length, array: array} = map_array, index \\ -1) do
    {valid_index?, value} =
      case fetch(map_array, index) do
        {:ok, value} ->
          {true, value}

        _error ->
          {false, nil}
      end

    if valid_index? do
      binary_index = to_binary_index!(index, length)
      integer_index = String.to_integer(binary_index)

      new_array = Enum.reduce((integer_index+1)..(length-1)//1, array, fn (index, array) ->
        from_binary_index = to_binary_index!(index)
        to_binary_index = to_binary_index!(index-1)
        Map.put(array, to_binary_index, Map.get(array, from_binary_index))
      end)
      new_array = Map.delete(new_array, to_binary_index!(length-1))

      new_length = length - 1

      new_map_array = %{map_array | length: new_length, array: new_array}

      {value, new_map_array}
    else
      {nil, map_array}
    end
  end

  @doc """
  Shifts `index` and higher indices by 1. Adds `value` to `map_array` at `index`.

  If insert is successful, returns `{:ok, updated_map_array}`, else return `:error`.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> {:ok, map_array} = MapArray.push(map_array, 2, 3)
      iex> map_array
      #MapArray<[0, 1, 3, 2]>

  """
  @spec push(t, index, value) :: {:ok, updated_map_array :: t} | :error
  def push(%__MODULE__{length: length, array: array} = map_array, index \\ -1, value) do
    with {:ok, binary_index} <- to_binary_index(index, length + 1),
         integer_index = String.to_integer(binary_index),
         true <- integer_index <= length
    do
      new_array = Enum.reduce(length..(integer_index+1)//-1, array, fn (index, array) ->
        to_binary_index = to_binary_index!(index)
        from_binary_index = to_binary_index!(index-1)
        Map.put(array, to_binary_index, Map.get(array, from_binary_index))
      end)
      new_array = Map.put(new_array, binary_index, value)

      new_length = length + 1

      new_map_array = %{map_array | length: new_length, array: new_array}

      {:ok, new_map_array}
    else
      _error ->
        :error
    end
  end

  @doc """
  Shifts `index` and higher indices by 1. Adds `value` to `map_array` at `index`. Raises error if `index` is out of
  bounds.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> MapArray.push!(map_array, 2, 3)
      #MapArray<[0, 1, 3, 2]>

  """
  @spec push!(t, index, value) :: updated_map_array :: t
  def push!(%__MODULE__{} = map_array, index \\ - 1, value) do
    _binary_index = to_binary_index!(index)

    case push(map_array, index, value) do
      {:ok, new_map_array} ->
        new_map_array

      _error ->
        raise("index out of bounds")
    end
  end

  @doc """
  Adds `value` to the end of `map_array`.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> MapArray.append(map_array, 3)
      #MapArray<[0, 1, 2, 3]>

  """
  @spec append(t, value) :: updated_map_array :: t
  def append(%__MODULE__{length: length} = map_array, value) do
    push!(map_array, length, value)
  end

  @doc """
  Adds `value` to the beginning of `map_array`.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> MapArray.prepend(map_array, 3)
      #MapArray<[3, 0, 1, 2]>

  """
  @spec prepend(t, value) :: updated_map_array :: t
  def prepend(%__MODULE__{} = map_array, value) do
    push!(map_array, 0, value)
  end

  @doc """
  Returns the size of `map_array`.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> MapArray.size(map_array)
      3

  """
  @spec size(t) :: integer
  def size(%__MODULE__{length: length}) do
    length
  end

  @doc """
  Converts `map_array` to list.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> MapArray.to_list(map_array)
      [0, 1, 2]

  """
  @spec to_list(t) :: list
  def to_list(%__MODULE__{length: length, array: array}) do
    for index <- 0..(length-1)//1 do
      array[Integer.to_string(index)]
    end
  end

  @doc """
  Converts a list to map array.

  ## Examples

      iex> list = [0, 1, 2]
      iex> MapArray.from_list(list)
      #MapArray<[0, 1, 2]>

  """
  @spec from_list(list) :: t
  def from_list(list) when is_list(list) do
    Enum.reduce(list, %MapArray{}, fn (element, accumulator) ->
      MapArray.append(accumulator, element)
    end)
  end

  @doc """
  Puts a value under `index` only if `index` alerady exists in `map_array`.

  If `map_array` contains `index`, then the value is returned as `{:ok, updated_map_array}`, else `:error` is returned.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> {:ok, map_array} = MapArray.replace(map_array, 0, 3)
      iex> map_array
      #MapArray<[3, 1, 2]>

  """
  @spec replace(t, index, value) :: {:ok, updated_map_array :: t} | :error
  def replace(%__MODULE__{length: length, array: array} =  map_array, index, value) do
    with {:ok, binary_index} <- to_binary_index(index, length),
         {:ok, _value} <- fetch(map_array, binary_index)
    do
      new_array = Map.put(array, binary_index, value)
      new_map_array = %{map_array | array: new_array}
      {:ok, new_map_array}
    else
      _error ->
        :error
    end
  end

  @doc """
  Puts a value under `index` only if `index` alerady exists in `map_array`. Raises error if `map_array` doesn't contain
  `index`.

  ## Examples

      iex> list = [0, 1, 2]
      iex> map_array = MapArray.from_list(list)
      iex> MapArray.replace!(map_array, 0, 3)
      #MapArray<[3, 1, 2]>

  """
  @spec replace!(t, index, value) :: updated_map_array :: t
  def replace!(%__MODULE__{length: length, array: array} =  map_array, index, value) do
    binary_index = to_binary_index!(index, length)
    _value = fetch!(map_array, binary_index)
    new_array = Map.put(array, binary_index, value)
    %{map_array | array: new_array}
  end

  defimpl Collectable, for: MapArray do
    def into(map_array) do
      collector_function = fn
        accumulator, {:cont, element} ->
          MapArray.append(accumulator, element)

        accumulator, :done ->
          accumulator

        _accumulator, :halt ->
          :ok
      end

      {map_array, collector_function}
    end
  end

  defimpl Enumerable, for: MapArray do
    def count(map_array) do
      {:ok, MapArray.size(map_array)}
    end

    def member?(map_array, {index, value}) do
      {:ok, value === map_array[index]}
    end

    def member?(_map_array, _element) do
      {:ok, false}
    end

    def slice(map_array) do
      size = MapArray.size(map_array)
      {:ok, size, &Enumerable.List.slice(MapArray.to_list(map_array), &1, &2, size)}
    end

    def reduce(map_array, accumulator, function) do
      Enumerable.List.reduce(MapArray.to_list(map_array), accumulator, function)
    end
  end

  defimpl Inspect, for: MapArray do
    import Inspect.Algebra, only: [concat: 1, to_doc: 2]

    def inspect(map_array, opts) do
      concat(["#MapArray<", to_doc(MapArray.to_list(map_array), opts), ">"])
    end
  end
end

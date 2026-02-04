defmodule IotaServiceTest do
  use ExUnit.Case
  doctest IotaService

  test "greets the world" do
    assert IotaService.hello() == :world
  end
end

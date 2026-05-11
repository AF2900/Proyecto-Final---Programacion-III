defmodule Apuesta do
  def crear(numero, tipo, cliente) do
    %{
      numero: numero,
      tipo: tipo,
      cliente: cliente
    }
  end
end

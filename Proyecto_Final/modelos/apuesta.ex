defmodule Apuesta do
  def crear(numero, tipo, cliente, fraccion \\ nil) do
    %{
      numero: numero,
      tipo: tipo,
      cliente: cliente,
      fraccion: fraccion
    }
  end
end

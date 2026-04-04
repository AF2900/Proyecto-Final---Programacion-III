defmodule Cliente do
  def crear(nombre, documento) do
    %{
      nombre: nombre,
      documento: documento,
      compras: []
    }
  end
end

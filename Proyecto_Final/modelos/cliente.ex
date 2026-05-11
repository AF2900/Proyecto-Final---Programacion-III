defmodule Cliente do
  defstruct nombre: "", edad: 0

  def crear(nombre, edad) do
    %Cliente{nombre: nombre, edad: edad}
  end

  def ingresar do
    nombre =
      "Ingrese nombre: "
      |> Util.ingresar(:texto)

    edad =
      "Ingrese edad: "
      |> Util.ingresar(:entero)

    crear(nombre, edad)
  end
end

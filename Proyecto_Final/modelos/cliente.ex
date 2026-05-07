defmodule Cliente do
  defstruct nombre: "", edad: 0, documento: "", contrasena: "", tarjeta: ""

  def crear(nombre, edad, documento, contrasena, tarjeta) do
    %Cliente{
      nombre: nombre,
      edad: edad,
      documento: documento,
      contrasena: contrasena,
      tarjeta: tarjeta
    }
  end

  def ingresar do
    nombre =
      "Ingrese nombre: "
      |> Util.ingresar(:texto)

    edad =
      "Ingrese edad: "
      |> Util.ingresar(:entero)

    documento =
      "Ingrese documento: "
      |> Util.ingresar(:texto)

    contrasena =
      "Ingrese contraseña: "
      |> Util.ingresar(:texto)

    tarjeta =
      "Ingrese tarjeta: "
      |> Util.ingresar(:texto)

    crear(nombre, edad, documento, contrasena, tarjeta)
  end
end

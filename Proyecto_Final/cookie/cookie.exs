Code.require_file("../util.ex", __DIR__)

defmodule Cookie do
  @longitud_llave 128

  def main do
    :crypto.strong_rand_bytes(@longitud_llave)
    |> Base.encode64()
    |> (fn llave ->
          File.write!("my_cookie", llave)
          Util.mostrar_mensaje(llave)
        end).()
  end
end

Cookie.main()

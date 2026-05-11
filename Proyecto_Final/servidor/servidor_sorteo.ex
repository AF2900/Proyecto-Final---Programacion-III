defmodule ServidorSorteo do
  def iniciar(sorteo) do
    spawn(fn -> loop(sorteo) end)
  end

  defp loop(sorteo) do
    receive do
      # Compra de billete completo
      {:comprar, cliente, numero, pid_cliente, pid_central} ->
        {nuevo_sorteo, respuesta} = vender_billete(sorteo, cliente, numero)
        send(pid_cliente, respuesta)
        send(pid_central, {:actualizar_sorteo, nuevo_sorteo})
        loop(nuevo_sorteo)

      # Compra de fracción de billete
      {:comprar_fraccion, cliente, numero_billete, numero_fraccion, pid_cliente, pid_central} ->
        {nuevo_sorteo, respuesta} = vender_fraccion(sorteo, cliente, numero_billete, numero_fraccion)
        send(pid_cliente, respuesta)
        send(pid_central, {:actualizar_sorteo, nuevo_sorteo})
        loop(nuevo_sorteo)

      {:obtener_info, pid_cliente} ->
        send(pid_cliente, {:respuesta, sorteo})
        loop(sorteo)

      {:obtener_apuestas, pid_cliente} ->
        send(pid_cliente, {:apuestas, Map.get(sorteo, :apuestas, [])})
        loop(sorteo)

      {:realizar_sorteo, pid_cliente, pid_central} ->
        {nuevo_sorteo, resultado} = realizar_sorteo(sorteo)
        send(pid_cliente, resultado)
        send(pid_central, {:actualizar_sorteo, nuevo_sorteo})
        loop(nuevo_sorteo)

      # Devolución de compra (billete completo o fracción)
      {:devolver_compra, nombre_cliente, numero_billete, tipo, numero_fraccion, pid_central} ->
        {nuevo_sorteo, respuesta} = devolver_compra(sorteo, nombre_cliente, numero_billete, tipo, numero_fraccion)
        send(pid_central, respuesta)
        case respuesta do
          {:ok, _} -> send(pid_central, {:actualizar_sorteo, nuevo_sorteo})
          _        -> :ok
        end
        loop(nuevo_sorteo)

      _ ->
        loop(sorteo)
    end
  end

  # ─── Venta de billete completo ────────────────────────────────
  defp vender_billete(sorteo, cliente, numero) do
    if sorteo.jugado do
      {sorteo, {:error, "El sorteo ya fue realizado"}}
    else
      case Enum.find(sorteo.billetes, fn b -> b.numero == numero end) do
        nil ->
          {sorteo, {:error, "Número de billete inválido"}}

        %{vendido: true} ->
          {sorteo, {:error, "El billete ##{numero} ya fue vendido completo"}}

        billete ->
          alguna_vendida = Enum.any?(billete.fracciones, fn f -> f.vendida end)

          if alguna_vendida do
            {sorteo, {:error, "El billete ##{numero} tiene fracciones vendidas, no se puede vender completo"}}
          else
            fracciones_vendidas = Enum.map(billete.fracciones, fn f -> %{f | vendida: true} end)
            nuevo_billete = %{billete | vendido: true, fracciones: fracciones_vendidas}

            nuevos_billetes =
              Enum.map(sorteo.billetes, fn b ->
                if b.numero == numero, do: nuevo_billete, else: b
              end)

            cliente_map = %{nombre: cliente.nombre, edad: cliente.edad}

            nueva_apuesta = %{
              cliente: cliente_map,
              numero: numero,
              tipo: :completo,
              fraccion: nil
            }

            nuevas_apuestas = sorteo.apuestas ++ [nueva_apuesta]
            nuevo_sorteo = %{sorteo | billetes: nuevos_billetes, apuestas: nuevas_apuestas}

            {nuevo_sorteo, {:ok, "#{cliente.nombre} compró el billete completo ##{numero}"}}
          end
      end
    end
  end

  # ─── Venta de fracción de billete ─────────────────────────────
  defp vender_fraccion(sorteo, cliente, numero_billete, numero_fraccion) do
    if sorteo.jugado do
      {sorteo, {:error, "El sorteo ya fue realizado"}}
    else
      case Enum.find(sorteo.billetes, fn b -> b.numero == numero_billete end) do
        nil ->
          {sorteo, {:error, "Número de billete inválido"}}

        %{vendido: true} ->
          {sorteo, {:error, "El billete ##{numero_billete} ya fue vendido completo"}}

        billete ->
          case Enum.find(billete.fracciones, fn f -> f.numero_fraccion == numero_fraccion end) do
            nil ->
              {sorteo, {:error, "Fracción ##{numero_fraccion} no existe en el billete ##{numero_billete}"}}

            %{vendida: true} ->
              {sorteo, {:error, "La fracción ##{numero_fraccion} del billete ##{numero_billete} ya fue vendida"}}

            fraccion ->
              nueva_fraccion = %{fraccion | vendida: true}
              nuevas_fracciones =
                Enum.map(billete.fracciones, fn f ->
                  if f.numero_fraccion == numero_fraccion, do: nueva_fraccion, else: f
                end)

              todas_vendidas = Enum.all?(nuevas_fracciones, fn f -> f.vendida end)
              nuevo_billete  = %{billete | fracciones: nuevas_fracciones, vendido: todas_vendidas}

              nuevos_billetes =
                Enum.map(sorteo.billetes, fn b ->
                  if b.numero == numero_billete, do: nuevo_billete, else: b
                end)

              cliente_map = %{nombre: cliente.nombre, edad: cliente.edad}

              nueva_apuesta = %{
                cliente: cliente_map,
                numero: numero_billete,
                tipo: :fraccion,
                fraccion: numero_fraccion
              }

              nuevas_apuestas = sorteo.apuestas ++ [nueva_apuesta]
              nuevo_sorteo    = %{sorteo | billetes: nuevos_billetes, apuestas: nuevas_apuestas}

              {nuevo_sorteo, {:ok, "#{cliente.nombre} compró la fracción ##{numero_fraccion} del billete ##{numero_billete}"}}
          end
      end
    end
  end

  # ─── Realizar sorteo ──────────────────────────────────────────
  defp realizar_sorteo(sorteo) do
    if sorteo.jugado do
      {sorteo, {:error, "El sorteo ya fue realizado"}}
    else
      vendidos = Enum.filter(sorteo.billetes, fn b -> b.vendido end)

      if vendidos == [] do
        {sorteo, {:error, "No hay billetes vendidos"}}
      else
        ganador = Enum.random(vendidos)

        apuestas_ganadoras =
          Enum.filter(sorteo.apuestas, fn a -> a.numero == ganador.numero end)

        nuevo_sorteo = %{sorteo | jugado: true, ganador: ganador.numero}

        premios        = Map.get(sorteo, :premios, [])
        fracciones_tot = Map.get(sorteo, :fracciones, 1)

        detalle_ganadores =
          apuestas_ganadoras
          |> Enum.map(fn a ->
            tipo_str = case a.tipo do
              :completo  -> "billete completo"
              "completo" -> "billete completo"
              :fraccion  -> "fracción ##{a.fraccion}"
              "fraccion" -> "fracción ##{a.fraccion}"
              _          -> "billete"
            end

            # Premio proporcional: completo recibe total, fracción recibe 1/N del total
            premio_recibido =
              Enum.map(premios, fn p ->
                monto =
                  case a.tipo do
                    t when t in [:completo, "completo"] -> p.valor
                    _ -> div(p.valor, max(fracciones_tot, 1))
                  end
                "#{p.nombre}: $#{monto}"
              end)

            premio_str = if premio_recibido == [], do: "", else: " [Premios: #{Enum.join(premio_recibido, ", ")}]"
            "#{a.cliente.nombre} (#{tipo_str})#{premio_str}"
          end)
          |> Enum.join(", ")

        mensaje =
          if apuestas_ganadoras == [] do
            "Número ganador: #{ganador.numero} — Sin ganadores registrados"
          else
            "Número ganador: #{ganador.numero} — Ganadores: #{detalle_ganadores}"
          end

        {nuevo_sorteo, {:ok, mensaje}}
      end
    end
  end

  # ─── Devolución de compra ─────────────────────────────────────
  defp devolver_compra(sorteo, nombre_cliente, numero_billete, tipo, numero_fraccion) do
    if sorteo.jugado do
      {sorteo, {:error, "No se puede devolver: el sorteo ya fue realizado"}}
    else
      tipo_atom = if is_atom(tipo), do: tipo, else: String.to_atom(tipo)

      apuesta_encontrada =
        Enum.find(sorteo.apuestas, fn a ->
          nombre_match   = a.cliente.nombre == nombre_cliente
          numero_match   = a.numero == numero_billete
          tipo_match     = a.tipo == tipo_atom or to_string(a.tipo) == to_string(tipo_atom)
          fraccion_match =
            case tipo_atom do
              :fraccion -> a.fraccion == numero_fraccion
              _         -> true
            end
          nombre_match and numero_match and tipo_match and fraccion_match
        end)

      case apuesta_encontrada do
        nil ->
          {sorteo, {:error, "No se encontró la compra para devolver"}}

        apuesta ->
          nuevas_apuestas = List.delete(sorteo.apuestas, apuesta)

          nuevos_billetes =
            Enum.map(sorteo.billetes, fn b ->
              if b.numero == numero_billete do
                case tipo_atom do
                  :completo ->
                    fracciones_rest = Enum.map(b.fracciones, fn f -> %{f | vendida: false} end)
                    %{b | vendido: false, fracciones: fracciones_rest}

                  :fraccion ->
                    fracciones_rest =
                      Enum.map(b.fracciones, fn f ->
                        if f.numero_fraccion == numero_fraccion, do: %{f | vendida: false}, else: f
                      end)
                    todas_libres = Enum.all?(fracciones_rest, fn f -> not f.vendida end)
                    %{b | fracciones: fracciones_rest, vendido: if(todas_libres, do: false, else: b.vendido)}

                  _ -> b
                end
              else
                b
              end
            end)

          nuevo_sorteo = %{sorteo | apuestas: nuevas_apuestas, billetes: nuevos_billetes}
          tipo_str     = if tipo_atom == :completo,
            do:   "billete completo ##{numero_billete}",
            else: "fracción ##{numero_fraccion} del billete ##{numero_billete}"

          {nuevo_sorteo, {:ok, "Compra devuelta: #{nombre_cliente} — #{tipo_str}"}}
      end
    end
  end
end

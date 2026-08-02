# frozen_string_literal: true

# Correcao da 20260802180000, que rodou e afetou ZERO contas.
#
# Aquela migration filtrava por CHAVE AUSENTE:
#
#   WHERE NOT (COALESCE(settings, '{}'::jsonb) ? 'auto_resolve_after')
#
# A premissa era "chave presente == o cliente desligou de proposito, nao mexer".
# Errado. O Chatwoot grava TODAS as chaves de settings assim que alguem abre e
# salva Configuracoes -> Geral, com null nas que estao vazias. Medido em dev:
#
#   "settings": { "auto_resolve_after": null, "auto_resolve_label": null,
#                 "auto_resolve_ignore_waiting": false, ... }
#
# Ou seja: em conta madura a chave sempre existe, o filtro nunca casa, e o
# backfill nao faz nada. O Label saiu (statement seguinte, sem esse filtro) —
# por isso o sintoma foi etiqueta criada e config nula.
#
# CRITERIO CERTO: valor NULO. Para `auto_resolve_after`, null E o estado
# "desligado" — nao existe como distinguir "nunca configurou" de "desligou",
# porque os dois gravam a mesma coisa.
#
# O respeito a escolha do cliente vem da natureza da migration, nao do filtro:
# ela roda UMA vez. Quem desligar depois disso fica desligado para sempre.
#
# (No audio_alerts o criterio de chave ausente esta correto e fica como esta:
# la "desligado" e o valor explicito 'none', nao null.)

class BackfillAutoResolveOnNull < ActiveRecord::Migration[7.1]
  def up
    execute(<<~SQL.squish)
      UPDATE accounts
         SET settings = COALESCE(settings, '{}'::jsonb) || jsonb_build_object(
               'auto_resolve_after', 1440,
               'auto_resolve_ignore_waiting', true,
               'auto_resolve_label', 'auto-resolvida-inatividade'
             ),
             updated_at = NOW()
       WHERE (COALESCE(settings, '{}'::jsonb) ->> 'auto_resolve_after') IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

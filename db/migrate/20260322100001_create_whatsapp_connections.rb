# frozen_string_literal: true

class CreateWhatsappConnections < ActiveRecord::Migration[7.0]
  def change
    create_table :whatsapp_connections do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :provider, null: false # meta_cloud, evolution
      t.string :name, null: false
      t.jsonb :credentials, default: {}
      t.jsonb :message_templates, default: []
      t.datetime :message_templates_last_updated
      t.string :status, default: 'active', null: false

      t.timestamps
    end

    add_index :whatsapp_connections, [:account_id, :provider]
  end
end

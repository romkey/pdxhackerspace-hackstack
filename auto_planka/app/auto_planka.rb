#! /usr/bin/env ruby

require 'pg'
require 'json'
require 'dotenv/load'

def _to_sql_list(array)
  array.map { |elt| "'#{elt}'" }.join(',')
end

def _get_public_board_ids(config, db)
  q = "SELECT * FROM board WHERE project_id IN ( #{_to_sql_list(config[:public_project_ids])} )"
  boards = db.exec(q)
  boards.map { |board| board['id'] }
end

# make_board_public by adding all users to a board
def make_projects_public(config, db, timestamp, public_board_ids)
  users = db.exec("SELECT * FROM user_account")

  config[:public_project_ids].each do |project_id|
    public_board_ids.each do |board_id|
      users.each do |user|
        user_id = user['id']
        db.exec("INSERT INTO board_membership VALUES (next_id(), '#{board_id}', '#{user_id}', '#{timestamp}', NULL, 'editor', NULL) ON CONFLICT DO NOTHING");
      end
    end
  end
end

# make_labels_public by adding every label from all boards in a project
# that contains public boards 
def make_labels_public(config, db, timestamp, public_board_ids)
  labels = db.exec("SELECT DISTINCT ON ( name ) * FROM label WHERE board_id IN ( #{_to_sql_list(public_board_ids)}) ORDER BY name, created_at");
  labels.each do |label|
    public_board_ids.each do |board_id|
      db.exec("INSERT INTO label VALUES ( next_id(), '#{board_id}', '#{label["name"]}', '#{label["color"]}', '#{timestamp}', NULL, '#{label["position"]}') ON CONFLICT DO NOTHING")
    end
  end
end

# make_admins_public_project_managers by adding all Planka admin
# accounts as managers on each project that contains public boards
def make_admins_public_project_managers(config, db, timestamp)
  admins = db.exec("SELECT * FROM user_account WHERE is_admin = 't'")

  config[:public_project_ids].each do |project_id|
    admins.each do |admin|
      admin_id = admin["id"]
      db.exec("INSERT INTO project_manager VALUES (next_id(), '#{project_id}', '#{admin_id}', '#{timestamp}', NULL) ON CONFLICT DO NOTHING")
    end
  end
end

db = PG.connect(ENV['POSTGRESQL'])

config = JSON.parse(File.read('config.json'), symbolize_names: true)

#results = db.exec("SELECT * from BOARD")
#results.each do |row|
#  puts row['name'], row['id']
#end

loop do 
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S.%L')

  public_board_ids = _get_public_board_ids(config, db)

  make_projects_public(config, db, timestamp, public_board_ids)
  puts 'made projects public'

  make_admins_public_project_managers(config, db, timestamp)
  puts 'made admins managers'

  make_labels_public(config, db, timestamp, public_board_ids)
  puts 'propogated labels'

  sleep(60)
end


# INSERT ... ON CONFLICT DO NOTHING/UPDATE
# https://stackoverflow.com/questions/4069718/postgres-insert-if-does-not-exist-already

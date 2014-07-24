#!/usr/bin/ruby
#
# configure to config.yml
#
require 'rubygems'
require 'mysql'
require 'yaml'
require 'optparse'

# コマンドライン引数からコンフィグファイルを取得
opts = Hash::new
opts[:c] = "config.yml"
opt = OptionParser.new
opt.on('-c CONF_FILE'){|v| opts[:c] = v}
opt.parse!(ARGV)

$config = Hash::new

# 生成するレコード数
$config["gen_record_max"] = 2000

# 生成時のプライマリとユニークキーの初期値
$config["gen_values"] = Hash::new
$config["gen_values"]["pri_first"] = 100000000
$config["gen_values"]["pri_count"] = 0
$config["gen_values"]["uni_first"] = 100000000
$config["gen_values"]["uni_count"] = 0

# db接続ユーザー情報
$config["db_user"] = "bnaka"
$config["db_pass"] = "bnaka"

# dbリスト
$config["db_list"] = Hash::new
def add_db_list(name, host)
	db = Hash::new
	db["name"] = name
	db["host"] = host
	$config["db_list"][name + "_db"] = db
end
######
add_db_list("test", "localhost")
add_db_list("test2", "localhost")
######

# 除外するテーブル
ignore_tables = Array::new
ignore_tables << "ignore_table"

# dbからテーブルリストを取得
$config["db_list"].each do |db|
	db_host = db[1]["host"]
	db_user = $config["db_user"]
	db_pass = $config["db_pass"]
	db_name = db[1]["name"]
	mysql = Mysql::new(db_host,db_user,db_pass,db_name)
	
	tables = Array::new
	mysql.query("show tables").each do |table|
		tables << table[0] unless ignore_tables.include?(table[0])
	end

	$config["db_list"][db[0]]["tables"] = tables
end

# 出力するYAMLをソートさせる
class Hash
  # Replacing the to_yaml function so it'll serialize hashes sorted (by their keys)
  #
  # Original function is in /usr/lib/ruby/1.8/yaml/rubytypes.rb
  def to_yaml( opts = {} )
    YAML::quick_emit( object_id, opts ) do |out|
      out.map( taguri, to_yaml_style ) do |map|
        sort.each do |k, v|   # <-- here's my addition (the 'sort')
          map.add( k, v )
        end
      end
    end
  end
end

# YAML形式で出力
open(opts[:c],"w") do |f|
	YAML.dump($config,f)
end

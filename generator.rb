#!/usr/bin/ruby
#
# MySQL テストデータ生成
#
require 'rubygems'
require 'mysql'
require 'yaml'
require 'fileutils'
require 'securerandom'
require 'optparse'

# コマンドライン引数からコンフィグファイルを取得
opts = Hash::new
opts[:c] = "config.yml"
opt = OptionParser.new
opt.on('-c CONF_FILE'){|v| opts[:c] = v}
opt.parse!(ARGV)

$config = YAML.load_file(opts[:c])

# カラムに合わせた関数オブジェクトと名前を取得
def db_get_table_columns_info(db, table)
	columns_name = Array::new
	columns_func = Array::new

	db.query("show columns from #{table}").each do |columns|
		name = columns[0]
		type = columns[1].split(/[\(\)]/)[0]
		num = columns[1].split(/[\(\)]/)[1].to_i
		key = columns[3]

		pri_func = lambda {
			$config["gen_values"]["pri_count"] += 1
			return $config["gen_values"]["pri_first"] + $config["gen_values"]["pri_count"]
		}
		uni_func = lambda {
			$config["gen_values"]["uni_count"] += 1
			return $config["gen_values"]["uni_first"] + $config["gen_values"]["uni_count"]
		}
		type_get_func = lambda {|type|
			func = nil
			case type
			when "tinyint"
				func = lambda { return rand 128 }
			when "smallint"
				func = lambda { return rand 10000 }
			when "int"
				func = lambda { return rand 100000000 }
			when "bigint"
				func = lambda { return rand 1000000000 }
			when "bool"
				func = lambda { return rand 2 }
			when "char", "varchar", "binary", "varbinary"
				func = lambda { return SecureRandom.hex(num/2) }
			when "text", "blob"
				func = lambda { return SecureRandom.hex(32) }
			when "date", "datetime", "timestamp", "time"
				func = lambda { return Time.at(rand * Time.now.to_i).strftime("%Y-%m-%d %H:%M:%S") }
			else
				p table + "." + type
				exit
			end
			return func
		}

		func = nil
		case key
		when "PRI"
			# intかbigintのみ完全にユニークな値を使うようにする
			# 他のものは意図が汲み取れないのでランダムのまま(複合キーだったりするハズ)
			case type
			when "int", "bigint"
				func = pri_func
			else
				func = type_get_func.call(type)
			end
		when "UNI"
			case type
			when "int", "bigint"
				func = uni_func
			else
				func = type_get_func.call(type)
			end
		else
			func = type_get_func.call(type)
		end

		columns_name << name
		columns_func << func
	end

	return [columns_name, columns_func]
end

# Insertに使うValuesを配列として取得
def db_gen_insert(db_name, table, columns)
	# db毎にディレクトリ作成
	dir_path = "./sql/#{db_name}"
	FileUtils.mkdir_p(dir_path) unless FileTest.exist?(dir_path)

	# ファイル作成
	file_path = dir_path + "/#{table}.sql"
	FileUtils.rm_f(file_path) if FileTest.exist?(file_path)

	columns_name = columns[0].join(",")
	columns_func = columns[1]

	# 生成するレコード数のINSERT文を作成
	values = Array::new
	(1..$config["gen_record_max"]).each do |cnt|
		val = ""
		val += "("
		columns_func.each do |func|
			val += "'#{func.call.to_s}',"
		end
		val.chomp!(",")
		val += ")"
		values << val

		# 1000件ずつINSERT文を作る
		if cnt % 1000 == 0 
			sql = "INSERT INTO #{table}(#{columns_name}) VALUES#{values.join(",")};\n"
			File.open(file_path, "a"){|f| f.write sql}
			values.clear
		end
	end
end

# テストデータ生成
def test_data_gen(db_conf)
	db_host = db_conf["host"]
	db_user = $config["db_user"]
	db_pass = $config["db_pass"]
	db_name = db_conf["name"]

	# DB接続
	db = Mysql::new(db_host,db_user,db_pass,db_name)

	# テーブルのカラム情報からInsert文作成
	db_conf["tables"].each do |table|
		columns = db_get_table_columns_info(db, table)
		db_gen_insert(db_name, table, columns)
	end
	
	# DB切断
	db.close()
end

# db毎にテストデータ生成
$config["db_list"].each do |db|
	test_data_gen(db[1])
end


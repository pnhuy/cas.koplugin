std = "luajit"
max_line_length = false
globals = {}
read_globals = { "G_reader_settings", "_" }
files["spec/**"] = { std = "+busted" }
exclude_files = { ".specify/**", ".claude/**" }
ignore = { "212/self" } -- KOReader callbacks take self by convention

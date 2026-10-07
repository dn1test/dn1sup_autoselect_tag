# frozen_string_literal: true

# Разовое чтение оглавления .rbz (STORE-архив pack.rb): парсинг центрального
# каталога ZIP без внешних гемов.
data = File.binread(File.join(__dir__, '..', 'dist', 'dn1sup_autoselect_tag-0.4.0.rbz'))
sig = "PK\x01\x02".b
names = []
pos = 0
while (idx = data.index(sig, pos))
  namelen = data[idx + 28, 2].unpack1('v')
  names << data[idx + 46, namelen]
  pos = idx + 4
end
puts names.sort

# Author: DN1Sup <dn1codegen@gmail.com>
# License: MIT

require 'sketchup.rb'
require 'extensions.rb'

# Loader-файл расширения. В .rbz лежит в корне архива как dn1sup_autoselect_tag.rb.
module Dn1sup
  module AutoSelectTag
    PLUGIN_ROOT = File.dirname(__FILE__).freeze

    extension = SketchupExtension.new('DN1Sup AutoSelect Tag', File.join(PLUGIN_ROOT, 'dn1sup_autoselect_tag', 'main'))
    extension.description = 'Автоматически назначает настраиваемые теги размерам и текстовым меткам. Имена тегов задаются в меню «Настройки...».'
    extension.version     = '0.3.1'
    extension.creator     = 'DN1Sup'
    extension.copyright   = '2026 DN1Sup <dn1codegen@gmail.com> (MIT)'
    extension.id          = 'dn1sup_autoselect_tag' if extension.respond_to?(:id=)

    Sketchup.register_extension(extension, true)
  end
end

# auto tag create and move object dimensions and labels to a self-named tag
# version 1.0
# dn1sucode (destudios@gmail.com)
# 04.02.2026
# License: MIT

module AutoTagDimensionLabel
  TAG_DIMENSION = "Dimension"
  TAG_LABEL = "Label"

  # Ensure a tag exists and return it.
  def self.ensure_tag(model, name)
    tags = model.layers
    tags[name] || tags.add(name)
  end

  # Assign a tag to an entity, ignoring failures for unsupported entities.
  def self.assign_tag(model, entity, name)
    tag = ensure_tag(model, name)
    return if entity.layer == tag
    entity.layer = tag
  rescue StandardError
    nil
  end

  # Observes entities collections to tag new dimensions and labels.
  class EntitiesObserver < Sketchup::EntitiesObserver
    # Tag newly added dimensions and text as they appear.
    def onElementAdded(entities, entity)
      model = entities.model
      if entity.is_a?(Sketchup::Dimension)
        AutoTagDimensionLabel.assign_tag(model, entity, TAG_DIMENSION)
      elsif entity.is_a?(Sketchup::Text)
        AutoTagDimensionLabel.assign_tag(model, entity, TAG_LABEL)
      end
    end
  end

  # Observes definition list changes (API class varies by SketchUp version).
  if defined?(Sketchup::DefinitionListObserver)
    class DefinitionsObserver < Sketchup::DefinitionListObserver
      # Attach entity observer to newly added component definitions.
      def onComponentAdded(definitions, definition)
        AutoTagDimensionLabel.attach_entities_observer(definition.entities)
      end
    end
  elsif defined?(Sketchup::DefinitionsObserver)
    class DefinitionsObserver < Sketchup::DefinitionsObserver
      # Attach entity observer to newly added component definitions.
      def onComponentAdded(definitions, definition)
        AutoTagDimensionLabel.attach_entities_observer(definition.entities)
      end
    end
  else
    DefinitionsObserver = nil
  end

  # Observes application events to attach model-level observers.
  class AppObserver < Sketchup::AppObserver
    # Hook observers for a new model.
    def onNewModel(model)
      AutoTagDimensionLabel.attach_model(model)
    end

    # Hook observers for an opened model.
    def onOpenModel(model)
      AutoTagDimensionLabel.attach_model(model)
    end
  end

  # Attach entity observer to a given entities collection.
  def self.attach_entities_observer(entities)
    return if entities.nil?
    @entities_observer ||= EntitiesObserver.new
    entities.add_observer(@entities_observer)
  end

  # Attach all observers needed for a model.
  def self.attach_model(model)
    return if model.nil?
    attach_entities_observer(model.entities)
    model.definitions.each { |definition| attach_entities_observer(definition.entities) }
    return unless DefinitionsObserver
    @definitions_observer ||= DefinitionsObserver.new
    model.definitions.add_observer(@definitions_observer)
  end

  # Install app-level observers once per session.
  def self.install
    return if @installed
    @installed = true
    @app_observer ||= AppObserver.new
    Sketchup.add_observer(@app_observer)
    attach_model(Sketchup.active_model)
  end
end

AutoTagDimensionLabel.install
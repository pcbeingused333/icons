# frozen_string_literal: true

require "nokogiri"

require "icons/icon/attributes"
require "icons/icon/configurable"

class Icons::SpriteIcon
  include Icons::Icon::Configurable

  # @param name [String] The icon name
  # @param library [String, Symbol] The icon library
  # @param variant [String, Symbol, nil] The icon variant (optional)
  # @param arguments [Hash] Additional attributes including class, data, stroke_width, etc.
  # @param sprite_location [String, nil] Override URL for the sprite file (optional)
  # @param config [Configuration] The configuration object (defaults to Icons.configuration)
  #
  def initialize(name:, library:, arguments:, variant: nil, sprite_location: nil, config: Icons.configuration)
    @config = config

    @name = name
    @library = library.to_sym
    @variant = (variant || set_variant)&.to_sym
    @arguments = arguments
    @sprite_location = sprite_location || @config.default_sprite_location
  end

  # Returns the SVG markup referencing the icon from a sprite sheet
  #
  # @return [String] The SVG markup using a `<use>` tag referencing the sprite symbol
  #
  # @raise [Icons::IconNotFound] If validate_sprite_icons is enabled and the icon does not exist
  #
  def svg
    if @config.validate_sprite_icons
      raise Icons::IconNotFound, error_message unless reference.exists?
    end

    sprite_svg
  end

  private

  def reference
    @reference ||= Icons::Sprite::Reference.new(name: @name, library: @library, variant: @variant)
  end

  def sprite_svg
    sprite_href = @sprite_location.nil? ? "##{reference.id}" : "#{@sprite_location}##{reference.id}"

    svg_content = <<~SVG
      <svg><use href="#{sprite_href}"></use></svg>
    SVG

    Nokogiri::HTML::DocumentFragment.parse(svg_content)
      .at_css("svg")
      .tap { |svg| attach_attributes(to: svg) }
      .to_html
  end

  # The sprite symbol must not carry the root `fill`/`stroke` of the source icon: attributes set on a
  # `<symbol>` win over the ones inherited from the `<svg>` that references it, so a per-icon override
  # (`arguments: {fill: "red"}`) would be ignored. They are set on the `<svg>` instead, as defaults.
  PRESENTATION_ATTRIBUTES = %w[fill stroke stroke-linecap stroke-linejoin].freeze

  def default_attributes
    root_presentation_attributes.merge(super)
  end

  def root_presentation_attributes
    return {} unless reference.exists?

    root = Nokogiri::XML(File.read(reference.file_path)).at_css("svg")

    PRESENTATION_ATTRIBUTES.each_with_object({}) do |name, attributes|
      attributes[name.to_sym] = root[name] if root&.[](name)
    end
  rescue Icons::IconNotFound
    {}
  end
end

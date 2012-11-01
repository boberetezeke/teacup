# Adds methods to the UIViewController class to make defining a layout and
# stylesheet very easy.  Also provides rotation methods that analyze
class UIViewController
  include Teacup::Layout

  class << self
    attr_reader :layout_definition

    # Define the layout of a controller's view.
    #
    # This function is analogous to Teacup::Layout#layout, though it is
    # designed so you can create an entire layout in a declarative manner in
    # your controller.
    #
    # The hope is that this declarativeness will allow us to automatically
    # deal with common iOS programming tasks (like releasing views when
    # low-memory conditions occur) for you. This is still not implemented
    # though.
    #
    # @param name  The stylename for your controller's view.
    #
    # @param properties  Any extra styles that you want to apply.
    #
    # @param &block  The block in which you should define your layout.
    #                It will be instance_exec'd in the context of a
    #                controller instance.
    #
    # @example
    #   MyViewController < UIViewController
    #     layout :my_view do
    #       subview UILabel, title: "Test"
    #       subview UITextField, {
    #         frame: [[200, 200], [100, 100]]
    #         delegate: self
    #       }
    #       subview UIView, :shiny_thing) {
    #         subview UIView, :centre_of_shiny_thing
    #       }
    #     end
    #   end
    #
    def layout(stylename=nil, properties={}, &block)
      @layout_definition = [stylename, properties, block]
    end

    def stylesheet(new_stylesheet=nil)
      if new_stylesheet.nil?
        return @stylesheet
      end

      @stylesheet = new_stylesheet
    end

  end # class << self

  # Returns a stylesheet to use to style the contents of this controller's
  # view.  You can also assign a stylesheet to {stylesheet=}, which will in
  # turn call {restyle!}.
  #
  # This method will be queried each time {restyle!} is called, and also
  # implicitly whenever Teacup needs to draw your layout (currently only at
  # view load time).
  #
  # @return Teacup::Stylesheet
  #
  # @example
  #
  #  def stylesheet
  #    if [UIInterfaceOrientationLandscapeLeft,
  #        UIInterfaceOrientationLandscapeRight].include?(UIInterface.currentDevice.orientation)
  #      Teacup::Stylesheet[:ipad]
  #    else
  #      Teacup::Stylesheet[:ipadvertical]
  #    end
  #  end
  def stylesheet
    @stylesheet
  end

  # Assigning a new stylesheet triggers {restyle!}, so do this during a
  # rotation to get your different layouts applied.
  #
  # Assigning a stylesheet is an *alternative* to returning a Stylesheet in
  # the {stylesheet} method. Note that {restyle!} calls {stylesheet}, so while
  # assigning a stylesheet will trigger {restyle!}, your stylesheet will not
  # be picked up if you don't return it in a custom stylesheet method.
  #
  # @return Teacup::Stylesheet
  #
  # @example
  #
  #   stylesheet = Teacup::Stylesheet[:ipadhorizontal]
  #   stylesheet = :ipadhorizontal
  def stylesheet=(new_stylesheet)
    @stylesheet = new_stylesheet
    if self.view
      self.view.stylesheet = new_stylesheet
    end
  end

  def top_level_view
    return self.view
  end


  # Instantiate the layout from the class, and then call layoutDidLoad.
  #
  # If you want to use Teacup in your controller, please hook into layoutDidLoad,
  # not viewDidLoad.
  def viewDidLoad
    # look for a layout_definition in the list of ancestors
    layout_definition = nil
    my_stylesheet = self.stylesheet
    parent_class = self.class
    while parent_class != NSObject and not (layout_definition && my_stylesheet)
      if not my_stylesheet and parent_class.respond_to?(:stylesheet)
        my_stylesheet = parent_class.stylesheet
      end

      if not layout_definition and parent_class.respond_to?(:layout_definition)
        layout_definition = parent_class.layout_definition
      end
      parent_class = parent_class.superclass
    end

    if my_stylesheet and not self.stylesheet
      self.stylesheet = my_stylesheet
    end

    if layout_definition
      stylename, properties, block = layout_definition
      layout(view, stylename, properties, &block)
    end

    layoutDidLoad
  end

  def viewWillAppear(animated)
    self.view.restyle!

    flow_views(self.view)
  end

  def flow_views(the_view)
    Flower.new(the_view.subviews.select{|sv| sv.position == :relative}, the_view.bounds.size).flow
    the_view.subviews.each do |subview|
      flow_views(subview)
    end
  end

  def layoutDidLoad
    true
  end

  # The compiling mechanisms combined with how UIKit works of rubymotion do
  # not allow the `shouldAutorotateToInterfaceOrientation` method to be
  # overridden in modules/extensions.  So instead, HERE is the code for what
  # `shouldAutorotateToInterfaceOrientation` should look like if you want
  # to use the teacup rotation stuff.  Call this method from your own
  # `shouldAutorotateToInterfaceOrientation` method.
  #
  # the teacup developers apologize for any inconvenience. :-)
  def autorotateToOrientation(orientation)
    if view.stylesheet and view.stylename
      properties = view.stylesheet.query(view.stylename, self, orientation)

      # check for orientation-specific properties
      case orientation
      when UIInterfaceOrientationPortrait
        # portrait is "on" by default, must be turned off explicitly
        if properties.supports?(:portrait) == nil and properties.supports?(:upside_up) == nil
          return true
        end

        return (properties.supports?(:portrait) or properties.supports?(:upside_up))
      when UIInterfaceOrientationPortraitUpsideDown
        if UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone
          # iphone must have an explicit upside-down style, otherwise this returns
          # false
          return properties.supports?(:upside_down)
        else
          # ipad can just have a portrait style
          return (properties.supports?(:portrait) or properties.supports?(:upside_down))
        end
      when UIInterfaceOrientationLandscapeLeft
        return (properties.supports?(:landscape) or properties.supports?(:landscape_left))
      when UIInterfaceOrientationLandscapeRight
        return (properties.supports?(:landscape) or properties.supports?(:landscape_right))
      end

      return false
    end

    return orientation == UIInterfaceOrientationPortrait
  end

  def willAnimateRotationToInterfaceOrientation(orientation, duration:duration)
    view.restyle!(orientation)
debug_this do
    flow_views(self.view)
end
  end

end

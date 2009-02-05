require File.dirname(__FILE__) + '/test_helper'

class Project
  def to_html
    'Generated HTML'
  end

  def to_xml
    'Generated XML'
  end

  [:to_json, :to_rss, :to_rjs].each do |method|
    undef_method method if respond_to? method
  end
end

class ProjectsController < ActionController::Base
  # Inherited respond_to definition is:
  # respond_to :html
  # respond_to :xml, :except => :edit
  respond_to :html
  respond_to :rjs => :edit
  respond_to :rss,  :only => 'index'
  respond_to :json, :except => :index

  def index
    respond_with(Project.new)
  end

  def respond_with_options
    respond_with(Project.new, :to => [:xml, :json], :location => 'http://test.host/')
  end

  def skip_not_acceptable
    respond_with(Project.new, :skip_not_acceptable => true)
    render :text => 'Will not raise double render error.'
  end

  def respond_to_with_resource
    respond_to(:with => Project.new)
  end

  def respond_to_with_resource_and_blocks
    respond_to(:with => Project.new) do |format|
      format.json { render :text => 'Render JSON' }
      format.rss  { render :text => 'Render RSS' }
    end
  end
end

class SuperProjectsController < ProjectsController
end

class RespondToUnitTest < TEST_CLASS
  def setup(class_controller = ProjectsController)
    @controller          = class_controller.new
    @controller.request  = @request  = ActionController::TestRequest.new
    @controller.response = @response = ActionController::TestResponse.new

    @formats    = @controller.formats_for_respond_to
    @responder  = ActionController::MimeResponds::Responder.new(@controller)
  end

  def test_respond_to_class_method_without_options
    assert_nil @formats[:html][:only]
    assert_nil @formats[:html][:except]
  end

  def test_respond_to_class_method_inheritance
    assert_nil   @formats[:xml][:only]
    assert_equal [:edit], @formats[:xml][:except]
  end

  def test_respond_to_class_method_with_implicit_only
    assert_equal [:edit], @formats[:rjs][:only]
    assert_nil   @formats[:rjs][:except]
  end

  def test_respond_to_class_method_with_explicit_only
    assert_equal [:index], @formats[:rss][:only]
    assert_nil   @formats[:rss][:except]
  end

  def test_respond_to_class_method_with_explicit_except
    assert_nil   @formats[:json][:only]
    assert_equal [:index], @formats[:json][:except]
  end

  def test_action_respond_to_format
    @controller.action_name = 'index'
    assert @responder.action_respond_to_format?('html')  # defined
    assert @responder.action_respond_to_format?('xml')   # inherited
    assert @responder.action_respond_to_format?('rss')   # explicit only
    assert !@responder.action_respond_to_format?('json') # exception

    @controller.action_name = 'edit'
    assert !@responder.action_respond_to_format?('xml')  # inherited
    assert @responder.action_respond_to_format?('rjs')   # implicit only
    assert @responder.action_respond_to_format?('json')  # exception
  end

  def test_action_respond_to_format_with_additional_mimes
    assert @responder.action_respond_to_format?('html', [:xml, :html, :json])
    assert !@responder.action_respond_to_format?('html', [:xml, :rss, :json])

    @controller.action_name = 'index'
    assert @responder.action_respond_to_format?('html', [])
    assert !@responder.action_respond_to_format?('json', [])
  end

  def test_clear_respond_to
    setup(SuperProjectsController)

    # Those responses are inherited from ProjectsController
    @controller.action_name = 'index'
    assert @responder.action_respond_to_format?('html')  # defined
    assert @responder.action_respond_to_format?('xml')   # inherited
    assert @responder.action_respond_to_format?('rss')   # explicit only

    # Let's clear respond_to definitions
    SuperProjectsController.send(:clear_respond_to!)

    assert !@responder.action_respond_to_format?('html')
    assert !@responder.action_respond_to_format?('xml')
    assert !@responder.action_respond_to_format?('rss')
  end

  def test_respond_to_block_does_not_respond_to_mime_all
    prepare_responder_to_respond!

    @responder.respond_to_block
    assert !@performed
    assert !@responder.responded?

    @responder.respond
    assert @performed
  end

  def test_respond_to_all_responds_to_mime_all
    prepare_responder_to_respond!

    @responder.respond_to_all
    assert @performed
    assert @responder.responded?
  end

  def test_respond_to_all_responds_only_to_all
    prepare_responder_to_respond!('text/html')

    @responder.respond_to_all
    assert !@performed
    assert !@responder.responded?
  end
 
  protected 
    def prepare_responder_to_respond!(content_type = '*/*')
      @request.accept = content_type
      @responder  = ActionController::MimeResponds::Responder.new(@controller)
      @performed = false

      # Mock template
      template = mock()
      @response.stubs(:template).returns(template)
      template.stubs(:template_format=).returns(true)

      respond_to_declaration = proc { |format|
        format.html { @performed = true }
        format.xml  { }
      }

      respond_to_declaration.call(@responder)
    end
end

class RespondToFunctionalTest < TEST_CLASS
  def setup
    @controller          = ProjectsController.new
    @controller.request  = @request  = ActionController::TestRequest.new
    @controller.response = @response = ActionController::TestResponse.new
  end

  def test_respond_with_layout_rendering
    @request.accept = 'text/html'
    get :index
    assert_equal 'Index HTML', @response.body.strip
  end

  def test_respond_with_calls_to_format_on_resource
    @request.accept = 'application/xml'
    get :index
    assert_equal 'Generated XML', @response.body.strip
  end

  def test_respond_with_inherits_format
    @request.accept = 'application/xml'
    get :index
    assert_equal 'Generated XML', @response.body.strip
  end

  def test_respond_with_renders_status_not_acceptable_if_mime_type_is_not_registered
    @request.accept = 'application/json'
    get :index
    assert_equal '406 Not Acceptable', @response.status
  end

  def test_respond_with_renders_not_found_when_mime_type_is_valid_but_could_not_render
    @request.accept = 'application/rss+xml'
    get :index
    assert_equal '404 Not Found', @response.status
  end

  def test_respond_to_all
    @request.accept = '*/*'
    get :index
    assert_equal 'Index HTML', @response.body.strip
  end

  def test_respond_with_sets_content_type_properly
    @request.accept = 'text/html'
    get :index
    assert_equal 'text/html', @response.content_type
    assert_equal :html, @response.template.template_format

    @request.accept = 'application/xml'
    get :index
    assert_equal 'application/xml', @response.content_type
    assert_equal :xml, @response.template.template_format
  end

  def test_respond_with_when_to_is_given_as_option
    @request.accept = 'text/html'
    get :respond_with_options
    assert_equal '406 Not Acceptable', @response.status

    @request.accept = 'application/xml'
    get :respond_with_options
    assert_equal 'Generated XML', @response.body.strip
  end

  def test_respond_with_forwads_extra_options_to_render
    @request.accept = 'application/xml'
    get :respond_with_options
    assert_equal 'Generated XML', @response.body.strip
    assert_equal 'http://test.host/', @response.headers['Location']
  end

  def test_respond_with_skips_head_when_skip_not_acceptable_is_given
    @request.accept = 'application/rss+xml'
    get :skip_not_acceptable
    assert_equal 'Will not raise double render error.', @response.body.strip
  end

  def test_respond_to_when_a_resource_is_given_as_option
    @request.accept = 'text/html'
    get :respond_to_with_resource
    assert_equal 'RespondTo HTML', @response.body.strip

    @request.accept = 'application/xml'
    get :respond_to_with_resource
    assert_equal 'Generated XML', @response.body.strip

    @request.accept = 'application/json'
    get :respond_to_with_resource
    assert_equal '404 Not Found', @response.status

    @request.accept = 'application/rss+xml'
    get :respond_to_with_resource
    assert_equal '406 Not Acceptable', @response.status
  end

  def test_respond_to_overwrite_class_method_definition
    @request.accept = 'application/rss+xml'
    get :respond_to_with_resource_and_blocks
    assert_equal 'Render RSS', @response.body.strip
  end

  def test_respond_to_fallback_to_first_block_when_mime_type_is_all
    @request.accept = '*/*'
    get :respond_to_with_resource_and_blocks
    assert_equal 'Render JSON', @response.body.strip
  end
end

require 'sinatra/base'
require './services/contentful'
require './lib/breadcrumbs'
require './lib/entry_state'
require './routes/errors'

# Base class for route middleware
module Routes
  class Base < Sinatra::Base
    include Errors
    include EntryState

    set :views, File.join(Dir.pwd, 'views')

    DEFAULT_API = 'cda'.freeze
    DEFAULT_LOCALE_CODE = 'en-US'.freeze
    DEFAULT_LOCALE = ::Contentful::Locale.new(
      'code' => DEFAULT_LOCALE_CODE,
      'name' => 'U.S. English',
      'default' => true
    )

    # Wrapper for the Contentful service
    def contentful
      Services::Contentful.instance(
        session[:space_id] || ENV['CONTENTFUL_SPACE_ID'],
        session[:delivery_token] || ENV['CONTENTFUL_DELIVERY_TOKEN'],
        session[:preview_token] || ENV['CONTENTFUL_PREVIEW_TOKEN']
      )
    end

    # Gets the selected API
    def api_id
      @api_id = params['api'] || DEFAULT_API
    end

    # Gets the current API data
    def current_api
      {
        cda: {
          label: I18n.translate('contentDeliveryApiLabel', locale.code),
          id: 'cda'
        },
        cpa: {
          label: I18n.translate('contentPreviewApiLabel', locale.code),
          id: 'cpa'
        }
      }[api_id.to_sym]
    end

    # Gets the selected locale
    def locale
      @locale ||= locales.detect { |locale| locale.code == (params['locale'] || DEFAULT_LOCALE_CODE) }
    rescue
      DEFAULT_LOCALE
    end

    # Gets all the available locales for the given space
    def locales
      @locales ||= contentful.space(api_id).locales
    rescue ::Contentful::Error
      [DEFAULT_LOCALE]
    end

    # Wrapper for the breadcrumb helper
    def raw_breadcrumbs
      Breadcrumbs.breadcrumbs(request, locale)
    end

    helpers do
      # Wrapper for template rendering with all shared global state
      def render_with_globals(template, locals: {})
        globals = {
          title: nil,
          current_locale: locale,
          current_api: current_api,
          current_path: request.path,
          query_string: request.query_string ? "?#{request.query_string}" : '',
          breadcrumbs: raw_breadcrumbs,
          editorial_features: session[:editorial_features],
          space_id: session[:space_id] || ENV['CONTENTFUL_SPACE_ID'],
          delivery_token: session[:delivery_token] || ENV['CONTENTFUL_DELIVERY_TOKEN'],
          preview_token: session[:preview_token] || ENV['CONTENTFUL_PREVIEW_TOKEN']
        }

        slim template, locals: globals.merge(locals)
      end

      # Helper for titles
      def format_meta_title(title, locale)
        return I18n.translate('defaultTitle', locale) unless title
        "#{title.capitalize} - #{I18n.translate('defaultTitle', locale)}"
      end
    end
  end
end

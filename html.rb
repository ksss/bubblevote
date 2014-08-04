class HTML
  @@single_tags = [:br, :img, :meta, :link]

  class << self
    def page (title)
      "<!doctype html>" +
      self.html {
        self.head {
          meta(:charset => "utf-8") +
          meta(:content => "width=device-width, initial-scale=1, maximum-scale=1", :name => :viewport) +
          link(:href => "/css/app.css", :rel => "stylesheet", :type => "text/css") +
          script({:src => "/js/jquery-2.0.2.js"}) +
          script({:src => "/js/app.js"}) +
          title{title}
        } + 
        self.body {
          application_header + div(:id => "content"){yield} + application_footer
        }
      }
    end

    def link_to(content, path, options=nil)
      gen_html(:a, {:href => path}.merge(options || {}), content)
    end

    def application_header; ''; end
    def application_footer; ''; end

    def method_missing(name, args={}, &block)
      if block_given?
        gen_html(name, args, class_eval(&block))
      else
        gen_html(name, args)
      end
    end

    def gen_html (name, attribute, content = '')
      name = name.to_s
      content = content.to_s
      attr = ''
      if 0 < attribute.length
        attr = ' ' + attribute.map { |key, value|
          "#{key.to_s}=\"#{value}\""
        }.join(' ')
      end

      if @@single_tags.include? name.to_sym
        "<#{name}#{attr}>\n"
      else
        "<#{name}#{attr}>#{content}</#{name}>\n"
      end
    end
  end
end
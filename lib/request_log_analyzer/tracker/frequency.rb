module RequestLogAnalyzer::Tracker

  # Catagorize requests by frequency.
  # Count and analyze requests for a specific attribute
  #
  # === Options
  # * <tt>:category</tt> Proc that handles the request categorization.
  # * <tt>:if</tt> Proc that has to return !nil for a request to be passed to the tracker.
  # * <tt>:line_type</tt> The line type that contains the duration field (determined by the category proc).
  # * <tt>:nils</tt> Track undetermined methods.
  # * <tt>:title</tt> Title do be displayed above the report.
  # * <tt>:unless</tt> Proc that has to return nil for a request to be passed to the tracker.
  #
  # The items in the update request hash are set during the creation of the Duration tracker.
  #
  # Example output:
  #  HTTP methods
  #  ----------------------------------------------------------------------
  #  GET    |  22248 hits (46.2%) |=================
  #  PUT    |  13685 hits (28.4%) |===========
  #  POST   |  11662 hits (24.2%) |=========
  #  DELETE |    512 hits (1.1%)  |
  class Frequency < Base

    attr_reader :categories

    # Check if categories are set up
    def prepare
      raise "No categorizer set up for category tracker #{self.inspect}" unless options[:category]
      @categorizer = create_lambda(options[:category])
      
      # Initialize the categories. Use the list of category names to 
      @categories = {}
      options[:all_categories].each { |cat| @categories[cat] = 0 } if options[:all_categories].kind_of?(Enumerable)
    end

    # Check HTTP method of a request and store that in the categories hash.
    # <tt>request</tt> The request.
    def update(request)
      cat = @categorizer.call(request)
      if cat || options[:nils]
        @categories[cat] ||= 0
        @categories[cat] += 1
      end
    end

    # Return the amount of times a HTTP method has been encountered
    # <tt>cat</tt> The HTTP method (:get, :put, :post or :delete)
    def frequency(cat)
      categories[cat] || 0
    end

    # Return the overall frequency
    def overall_frequency
      categories.inject(0) { |carry, item| carry + item[1] }
    end

    # Return the methods sorted by frequency
    def sorted_by_frequency
      @categories.sort { |a, b| b[1] <=> a[1] }
    end

    # Generate a HTTP method frequency report to the given output object.
    # Any options for the report should have been set during initialize.
    # <tt>output</tt> The output object
    def report(output)
      output.title(options[:title]) if options[:title]

      if @categories.empty?
        output << "None found.\n"
      else
        sorted_categories = @categories.sort { |a, b| b[1] <=> a[1] }
        total_hits        = sorted_categories.inject(0) { |carry, item| carry + item[1] }
        sorted_categories = sorted_categories.slice(0, output.options[:amount]) if output.options[:amount] && output.options[:amount] != :all

        output.table({:align => :left}, {:align => :right }, {:align => :right}, {:type => :ratio, :width => :rest}) do |rows|
          sorted_categories.each do |(cat, count)|
            rows << [cat, "#{count} hits", '%0.1f%%' % ((count.to_f / total_hits.to_f) * 100.0), (count.to_f / total_hits.to_f)]
          end
        end

      end
    end

    # Returns a hash with the categories of every category that can be exported to YAML
    def to_yaml_object
      return nil if @categories.empty?
      @categories
    end

    # Returns the title of this tracker for reports
    def title
      options[:title] || 'Request frequency'
    end
  end
end

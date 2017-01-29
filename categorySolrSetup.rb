#!/usr/bin/env ruby

require 'tiny_tds'
require 'engtagger'
require 'net/http'
require 'erb'
require 'json'
require 'csv'
require_relative './sqlhelpers.rb'

def getLeafCategories
  categories = Hash.new
  client = @sql.getClient
  sql = @sql.class::SQL_CATEGORIES
  result = client.execute(sql)
  result.each do |rowset|
    categories[rowset['DisplayName']] = rowset['CategoryId']
  end
  client.close
  return categories
end

def getLastNDescriptions(categoryid, samplesize)
  descriptions = ''
  brands = ''
  models = ''
  vendors = ''
  depreciation_category = ''
  client = @sql.getClient
  #TODO: Scrub terms e.g. BURNED FROM SITE
  sql = @sql.getOriginalDescriptionQuery(categoryid, samplesize)
  result = client.execute(sql)
  result.each do |rowset|
    descriptions << " " <<rowset['OriginalDescription']
    brands << " " <<rowset['OriginalBrand'] if !rowset['OriginalBrand'].nil?
    models << " " <<rowset['OriginalModel'] if !rowset['OriginalModel'].nil?
    vendors << " " <<rowset['OriginalVendor'] if !rowset['OriginalVendor'].nil?
    depreciation_category = rowset['DepreciationCategory']
  end
  client.close
  return descriptions, brands, models, vendors, depreciation_category
end

def postSolrUpdate(payload)
  request = Net::HTTP::Post.new(@solrUpdateUrl)
  request.add_field 'Content-Type', 'application/json'
  request.body = payload

  uri = URI.parse(@solrUpdateUrl)
  http = Net::HTTP.new(uri.host, uri.port)
  response = http.request(request)
  puts response if @debug > 0
end

def getTestDescriptions
  testdescriptions = Array.new
  client = @sql.getClient
  sql = @sql.class::SQL_TESTDESCRIPTIONS
  result = client.execute(sql)
  result.each do |rowset|
    terms = ''
    posOrigDescription = @tgr.get_nouns(@tgr.add_tags(rowset['OriginalDetailDescription']))
    posOrigDescription.each do |noun, count|
      i = 0
      while i < count do
          terms << " " + noun
          i = i += 1
        end
      end
      testdescriptions.push([rowset['CategoryId'], rowset['Category'], terms])
    end
    client.close
    return testdescriptions
  end

  def extractTerms(unscrubbedterms, pos)
    terms = ""
    orderedterms =  tagTerms(unscrubbedterms, pos)
    .sort_by {|term, count| -count}
    .first(30)
    #Loop through hash of terms and build document with noun repeated 'count' times
    orderedterms.each do |term, count|
      i = 0
      while i < count do
          terms << " " + term.gsub(',', ' ') if term.length > 1
          i = i += 1
        end
      end
      return terms
    end

    def tagTerms(unscrubbedterms, pos)
      case pos
      when 'nouns' then return @tgr.get_nouns(@tgr.add_tags(unscrubbedterms))
      when 'terms' then return @tgr.get_words(@tgr.add_tags(unscrubbedterms))
      else raise 'invalid pos action'
      end
    end

    #Main Flow

    #globals
    @debug = 1 #0 = off and 1 = on
    @samplesize = 500 #sets the number of original descriptions to parse
    @numberofcategories = 10 #set to 4000 to generate docs for all categories.  For testing, set to small number
    @sql = Sqlhelpers.new
    @tgr = EngTagger.new
    @solrUpdateUrl = 'http://localhost:8983/solr/category/update/json/docs'
    @solrSelectUrl = 'http://localhost:8983/solr/category/select?wt=json&q='
    @legacySolrDocOutputfile = '/Users/mgore/gitrepo/categorysolr/solr-home/category/conf/CategorySolrDoc.csv'

    #locals
    update = 'false'
    test = 'false'
    updatelegacy = 'false'

    ARGV.each do |a|
      case a
      when 'u' then update = 'true'
      when 't' then test = 'true'
      when 'l' then updatelegacy = 'true' #by default this will run update but instead up hitting @solrudpateurl it will output to a legacy formatted CSV
      else puts 'Invalid or missing params.  Only u and t and l are allowed'
      end
    end

    if update == 'true' or updatelegacy == 'true'
      cats = getLeafCategories
      if updatelegacy == 'true'
        File.delete(@legacySolrDocOutputfile) if File.exists?(@legacySolrDocOutputfile)
        legacysolrheader = File.read('templates/legacysolrheader.erb')
        legacyheadertemplate = ERB.new legacysolrheader
        header = legacyheadertemplate.result binding
        open(@legacySolrDocOutputfile,'w') do |csv|
          csv << header
        end
      end
      #loop through each category and create the solr document
      cats.take(@numberofcategories).each do |key , value|
        puts key
        terms = ''
        descriptions, brands, models, vendors, depreciation_category = getLastNDescriptions(value, @samplesize)

        if !descriptions.empty?
          terms << extractTerms(descriptions, 'nouns')
          #Extract brand, model and vendor terms
          brandterms = extractTerms(brands, 'terms') if !brands.empty?
          modelterms = extractTerms(models, 'terms') if !models.empty?
          vendorterms = extractTerms(vendors, 'terms') if !vendors.empty?
          terms << brandterms if !brandterms.nil?
          terms << modelterms if !modelterms.nil?
          terms << vendorterms if !vendorterms.nil?

          if update == 'true'
            #Populate the solr json template
            solrjson = File.read('templates/solrdocument.erb')
            template = ERB.new solrjson
            payload = template.result binding
            puts payload if @debug > 0
            postSolrUpdate(payload)
          end

          if updatelegacy == 'true'
            legacysolrrow = File.read('templates/legacysolrrow.erb')
            legacyrowtemplate = ERB.new legacysolrrow
            row = legacyrowtemplate.result binding
            open(@legacySolrDocOutputfile,'a'
            ) do |csv|
              csv.puts row
            end
          end
        end
      end
    end

    if test == 'true'
      testdescriptions = getTestDescriptions
      testdescriptions.each do |a|
        uri = URI.parse(URI.encode(@solrSelectUrl + a[2]))
        puts uri
        puts 'Original Description: ' + a[2]
        http = Net::HTTP.new(uri.host, uri.port)
        response = http.request(Net::HTTP::Get.new(uri.request_uri))
        body = JSON.parse(response.body)

        #puts 'number of matches = ' + body['response']['numFound'].to_s + '-- application category:  ' + a[1].to_s
        if body['responseHeader']['status'] == 0
          body['response']['docs'].each do |doc|
            puts 'result= ' + doc['category_description']
            if doc['depreciation_category'].nil?
              puts '| depcat: ' + 'NONE'
            else
              puts '| depcat: ' + doc['depreciation_category']
            end
          end
        end
      end
    end

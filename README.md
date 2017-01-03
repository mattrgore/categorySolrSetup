#Setup

#for connection to SQL Server data warehouse
gem install tiny_tds
#for Parts of Speech (POS) tagging and extraction
gem install engtagger 

#Usage

ruby categorySolrSetup.rb [options]

options:

u[Update] - Queries content item descriptions for all categories, parses most common terms, and updates solr core
t[Test] - Queries content items descriptions and queries solr and reports top 10 category results
l[Legacy] - Builds CSV file for import into legacy (v1) solrCategory core


#make sure to set the @solrUpdateURL to your local or development environment


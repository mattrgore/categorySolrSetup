#!/usr/bin/env ruby

class Sqlhelpers
	SQL_CATEGORIES = 'SELECT parent.CategoryId, parent.DisplayName FROM dimCategory parent LEFT JOIN dimCategory child ON parent.CategoryId = child.ParentCategoryId WHERE child.CategoryId is null AND parent.CategoryId != 3785'

	#SQL_ORIGINALDESCRIPTIONS = 'SELECT TOP %s UPPER(f.ContentItemDescription) AS OriginalDescription FROM DW_3_0.dbo.CE_Claimline_Fact f WHERE EVPCategoryId = %s AND f.ContentItemDescription IS NOT NULL AND CreatedDate > ''01-01-2016'''

	SQL_ORIGINALDESCRIPTIONS = 'SELECT TOP %s UPPER(f.ContentItemDescription) AS OriginalDescription, UPPER(c.Name) AS DepreciationCategory, UPPER(NULLIF(f.ContentItemBrand,"")) AS OriginalBrand, UPPER(NULLIF(f.ContentItemModel,"")) AS OriginalModel, UPPER(NULLIF(f.ContentItemVendor,"")) AS OriginalVendor FROM    DW_3_0.dbo.CE_Claimline_Fact f WITH (NOLOCK, INDEX(IX_TEMP)) INNER JOIN dbo.CE_dimCategory c ON f.DepreciationCategoryId = c.Id WHERE   EVPCategoryId = %s AND f.ContentItemDescription IS NOT NULL AND NULLIF(f.ContentItemBrand,"") IS NOT NULL AND CreatedDate > ''01-01-2016'''

	SQL_TESTDESCRIPTIONS = 'SELECT TOP 250 f.EVPCategoryId CategoryId, c.DisplayName as Category, f.OriginalDetailDescription FROM DW_3_0.dbo.CE_CompletedClaimLine_Fact f INNER JOIN dimCategory c ON f.EVPCategoryId = c.CategoryId WHERE CreatedDate > DATEADD(MONTH, -2, GETDATE());'

	def getClient
		return TinyTds::Client.new(:username => '', :password => '', :host => '', :port => '51001', :database => 'DW_3_0', :timeout => 60)
		#return TinyTds::Client.new(:username => '', :password => '', :dataserver => '10.203.4.26', :database => 'DW_3_0', :timeout => 60)
	end

	def getOriginalDescriptionQuery(categoryId, samplesize)
		return SQL_ORIGINALDESCRIPTIONS % [samplesize ,categoryId]
	end
end
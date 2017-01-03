USE DW_3_0;

--Used to get the leaf categories.  Each category will get it's own Solr document
SELECT  parent.CategoryId ,
        parent.DisplayName
FROM    dimCategory parent
        LEFT JOIN dimCategory child ON parent.CategoryId = child.ParentCategoryId
WHERE   child.CategoryId IS NULL;

--Used to get the descriptions to mine for common terms
SELECT TOP 500
        UPPER(f.ContentItemDescription) AS OriginalDescription,
		UPPER(c.Name) AS DepreciationDescription,
		UPPER(f.ContentItemBrand) AS OriginalBrand,
		UPPER(f.ContentItemModel) AS OriginalModel,
		UPPER(f.ContentItemVendor) AS OriginalVendor
FROM    DW_3_0.dbo.CE_Claimline_Fact f
WITH	(INDEX(IX_TEMP))
INNER JOIN dbo.CE_dimCategory c ON f.DepreciationCategoryId = c.Id
WHERE   EVPCategoryId = 923
        AND f.ContentItemDescription IS NOT NULL
		AND NULLIF(f.ContentItemBrand,'') IS NOT NULL
        AND CreatedDate > '01-01-2016';

--Used to get descriptions for testing
SELECT TOP 250
        f.EVPCategoryId CategoryId ,
        c.DisplayName AS Category ,
        f.OriginalDetailDescription
FROM    DW_3_0.dbo.CE_CompletedClaimLine_Fact f
        INNER JOIN dimCategory c ON f.EVPCategoryId = c.CategoryId
WHERE   CreatedDate > DATEADD(MONTH, -1, GETDATE());

SELECT * FROM dbo.CE_dimCategory
--This project focuses on fixing data quality issues such as missing data, incorrect formatting and duplicate data using SQL (MSSQL). The cleaned dataset will provide an accurate and consistent record which can be a master data source for business intelligence dashboards. 
--The dataset contains approx. 56.000 rows of data about housing market in Nashville, Texas, USA. Columns provide data about addresses, sales prices, building value etc. There data quality issues in this dataset are as follows:
--1.	Sale Date is in the format “2016-03-21 00:00:00.000”. The zeros represent an invalid timestamp because of incorrect Data Type classification in source data. 
--2.	Property address is missing several entries.
--3.	Property address and owner combines street address, city name and state into one entry. This limits street, city and state level filtering of data for future applications.
--4.	Sold As Vacant column contains entries Y, N, Yes, No. Probably a result of incorrect data entry. This creates disambiguation and reduces data clarity.
--5.	Some records are in duplicate. 


--------------------------------------------------------------------------------------------------------

--Step 1 
--Data transformation: 
--I remove the redundant and empty timestamp from all Sale Dates by converting its data type to Date and creating a new column with edited Sale dates. 

Select *
From PortfolioProject.dbo.NashvilleHousing


Select SaleDate, CONVERT(Date,SaleDate)
From PortfolioProject.dbo.NashvilleHousing

ALTER TABLE NashvilleHousing
Add SaleDateConverted Date;

Update NashvilleHousing
SET SaleDateConverted = CONVERT(Date,SaleDate)

Select SaleDateConverted, SaleDate
From PortfolioProject.dbo.NashvilleHousing


--------------------------------------------------------------------------------------------------------

--Step 2
--Filling out null values:
--Property address is missing several entries. Probably because of incorrect data entry in source data at time of resale or reclassification of property type based on Land Use. 
--I search the data for entries that match the parcel IDs of incomplete records and but are not themselves empty. 
--I copy the property address from the complete record to the incomplete record. 
--I avoid duplication by ensuring that the Unique ID of the of the records being copied do not match. 

Select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress,b.PropertyAddress)
From PortfolioProject.dbo.NashvilleHousing a
JOIN PortfolioProject.dbo.NashvilleHousing b
	on a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null

Update a
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress)
From PortfolioProject.dbo.NashvilleHousing a
JOIN PortfolioProject.dbo.NashvilleHousing b
	on a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null


--------------------------------------------------------------------------------------------------------

--Step 3 
--Data transformation: Breaking out Property and Owner Addresses into Individual Columns (Address, City, State). SUBSTRING() and PARSENAME() are used to demonstrate two methods.

SELECT
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1 ) as Address
, SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1 , LEN(PropertyAddress)) as Address

From PortfolioProject.dbo.NashvilleHousing


ALTER TABLE NashvilleHousing
Add PropertySplitAddress Nvarchar(255);

Update NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1 )


ALTER TABLE NashvilleHousing
Add PropertySplitCity Nvarchar(255);

Update NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1 , LEN(PropertyAddress))

Select
PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3)
,PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2)
,PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1)
From PortfolioProject.dbo.NashvilleHousing

ALTER TABLE NashvilleHousing
Add OwnerSplitAddress Nvarchar(255);

Update NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3)

ALTER TABLE NashvilleHousing
Add OwnerSplitCity Nvarchar(255);

Update NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2)

ALTER TABLE NashvilleHousing
Add OwnerSplitState Nvarchar(255);

Update NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1)


--------------------------------------------------------------------------------------------------------

--Step 4
--Remove Disambiguation: By changing Y and N to Yes and No in "Sold as Vacant" field.

Select Distinct(SoldAsVacant), Count(SoldAsVacant)
From PortfolioProject.dbo.NashvilleHousing
Group by SoldAsVacant
order by 2

Select SoldAsVacant
, CASE When SoldAsVacant = 'Y' THEN 'Yes'
	   When SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END
From PortfolioProject.dbo.NashvilleHousing

Update NashvilleHousing
SET SoldAsVacant = CASE When SoldAsVacant = 'Y' THEN 'Yes'
	   When SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END


--------------------------------------------------------------------------------------------------------

--Step 5: There are 104 duplicate records which I will delete now. 
--Note that it is best practice to maintain a separate copy of source dataset so duplicate records can be retrieved if needed in future. 
--A CTE and window functions will be used to achieve this result. 

WITH RowNumCTE AS(
Select *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num

From PortfolioProject.dbo.NashvilleHousing
)
Delete
From RowNumCTE
Where row_num > 1


-------------------------------------------------------------------------------------------------------

--Step 6: I will now remove the Sales date, property address and owner address columns since I have already created more usable versions of these columns. 
--Note that it is best practice to maintain a separate copy of source dataset so that original columns can be retrieved if needed. 

Select *
From PortfolioProject.dbo.NashvilleHousing


ALTER TABLE PortfolioProject.dbo.NashvilleHousing
DROP COLUMN OwnerAddress, PropertyAddress, SaleDate

----------------------------------------------------------------------------------------------------------

-- Thanks Alex Freberg for the inspiration for this project. 

-- =============================================
-- Author:		John George
-- Create date: 2017/02/13
-- Modify Date: 5/11/2017
-- Modifier:    Peter Prigge
-- Description:	Retrieves the Products for National Geographic
-- Modify Date: 7/26/2017
-- Modifier: 	David Swingle

-- Modify Date: 08/11/2017
-- Modifier: 	John George
-- Description: Replaced @PurchaserCreatorId with @CreatorName

-- Modify Date: 09/26/2017
-- Modifier: 	John George
-- Description: Changed @AccountName code so it searches on the agency name instead of the Purchaser person.

-- Modify Date: 10/04/2017
-- Modifier: 	Chris Frisbie
-- Description: Added a time range to search between. 

-- Modify Date:	11/09/2017
-- Modifier: 	John George
-- Description:	Add a second set of status type comparators to act as the upper bound. Allowing to search for status ranges.

-- Modify Date:	02/12/2018
-- Modifier: 	Peter Prigge
-- Description:	Removed hardcode values for Nat Geo defaults.  Made Supplier ID and an optional parameter for future multi suppliers.
-- =============================================

ALTER PROCEDURE [dbo].[wholesale_order_search] (
	@SellerId INT = NULL,
	@SupplierId INT = NULL,
	@AccountName VARCHAR(100) = NULL,
	@AccountId INT = NULL,
	@Passenger VARCHAR(100) = NULL,
	@BookingRef VARCHAR(1000) = NULL,
	@OrderId INT = NULL,
	@LineItemId INT = NULL,
	@TransactionId INT = NULL,
	@ProductBaseTypeId INT = NULL,
	@CheckProductActiveStatus BIT = NULL,
	@IsProductActive BIT = NULL,
	@ProductId INT = NULL,
	@City VARCHAR(100) = NULL,
	@SaleTypeId INT = NULL,
	@CustomerStatusComparator INT = NULL,
	@CustomerStatusType INT = NULL,
	@SupplierStatusComparator INT = NULL,
	@SupplierStatusType INT = NULL,
	@DeliveryStatusComparator INT = NULL,
	@DeliveryStatusType INT = NULL,
	@CustomerStatusTypeMax INT = NULL,
	@SupplierStatusTypeMax INT = NULL,	
	@DeliveryStatusTypeMax INT = NULL,
	@SupplierTransactionId VARCHAR(12) = NULL,
	@MethodOfDeliveryCode CHAR(2) = NULL,
	@OrderNotCancelled BIT = NULL,
	@EventRangeBegin DATETIME = NULL,
	@EventRangeEnd DATETIME = NULL,  	  
	@EventWeekDays VARCHAR(100) = NULL,
	@OrderRangeBegin DATETIME = NULL,
	@OrderRangeEnd DATETIME = NULL,
	@CreatorName VARCHAR(100) = NULL,
	@OurPriceCode CHAR(2) = NULL,
	@SupplierPriceCode VARCHAR(10) = NULL,
	@EventTimeBegin DATETIME = NULL,
	@EventTimeEnd DATETIME = NULL,
	@SalesVehicleId INT = NULL
)
AS
BEGIN
	SET NOCOUNT ON;

	IF LTRIM(RTRIM(@AccountName)) = '' SET @AccountName = NULL
	IF LTRIM(RTRIM(@Passenger)) = '' SET @Passenger = NULL
	IF LTRIM(RTRIM(@BookingRef)) = '' SET @BookingRef = NULL
	IF LTRIM(RTRIM(@City)) = '' SET @City = NULL
	IF LTRIM(RTRIM(@SupplierTransactionId)) = '' SET @SupplierTransactionId = NULL
	IF LTRIM(RTRIM(@MethodOfDeliveryCode)) = '' SET @MethodOfDeliveryCode = NULL
	IF LTRIM(RTRIM(@EventWeekDays)) = '' SET @EventWeekDays = NULL
	IF LTRIM(RTRIM(@OurPriceCode)) = '' SET @OurPriceCode = NULL
	IF LTRIM(RTRIM(@SupplierPriceCode)) = '' SET @SupplierPriceCode = NULL

	--National Geographic Seller and Supplier
	--SET @SellerId = ISNULL(@SellerId, 11);
	--SET @SupplierID = ISNULL (@SupplierId, 1000776)

	DECLARE @CustomerStatusCode VARCHAR(50)
	IF @CustomerStatusType IS NOT NULL
	BEGIN
		SET @CustomerStatusCode = (SELECT TOP 1 type_desc_name FROM dbo.type_desc WHERE TYPE_ID = @CustomerStatusType)
	END

	PRINT @CustomerStatusCode

	DECLARE @SupplierStatusCode VARCHAR(50)
	IF @SupplierStatusType IS NOT NULL
	BEGIN
		SET @SupplierStatusCode = (SELECT TOP 1 type_desc_name FROM dbo.type_desc WHERE TYPE_ID = @SupplierStatusType)
	END

	DECLARE @DeliveryStatusCode VARCHAR(50)
	IF @DeliveryStatusType IS NOT NULL
	BEGIN
		SET @DeliveryStatusCode = (SELECT TOP 1 type_desc_name FROM dbo.type_desc WHERE TYPE_ID = @DeliveryStatusType)
	END

	PRINT @SupplierStatusCode

	SELECT TOP 1000
		filtered_purchase.mod AS 'method_of_delivery_code',
		agency.name AS 'account_name',
		purchase_line_item.purchase_line_item_id,
		offer.offer_name AS 'product',
		filtered_purchase.purchase_history_id AS 'order_id',
		purchase_line_item_detail.product_datetime,
		purchase_line_item.qty,
		purchase_line_item_detail.[description] AS 'description',
		purchase_line_item_detail.sale_status_type_id,
		purchase_line_item_detail.supplier_status_type_id,
		purchase_line_item_detail.delivery_status_type_id,
		passenger_person.first_name,
		passenger_person.last_name,
		memo.memo AS 'booking_ref'
	FROM (
		SELECT DISTINCT
			purchase.purchase_history_id ,
            purchase.purchaser_id ,
            purchase.received_by_person_id,
			tix.mod
		FROM dbo.purchase_history purchase
		LEFT JOIN dbo.person passenger_person
			ON passenger_person.person_id = purchase.received_by_person_id

		OUTER APPLY(SELECT * FROM dbo.ufn_get_memo_by_history_id(purchase.purchase_history_id, 1190)) AS purchase_ref_memo -- Reference Memo

		INNER JOIN dbo.purchaser purchaser
			ON purchaser.purchaser_id = purchase.purchaser_id	 AND purchaser.agency_id IS NOT NULL		
		INNER JOIN dbo.person purchaser_person
			ON purchaser_person.person_id = purchaser.person_id
		INNER JOIN dbo.agency agency
			ON agency.agency_id = purchaser.agency_id
		INNER JOIN dbo.purchase_line_item line_item
			ON line_item.purchase_history_id = purchase.purchase_history_id
		INNER JOIN dbo.purchase_line_item_detail line_item_detail
			ON line_item_detail.purchase_line_item_id = line_item.purchase_line_item_id
		LEFT JOIN dbo.type_desc sale_status_type_detail
			ON sale_status_type_detail.type_id = line_item_detail.sale_status_type_id
		LEFT JOIN dbo.type_desc supplier_status_type_detail
			ON supplier_status_type_detail.type_id = line_item_detail.supplier_status_type_id 
		LEFT JOIN dbo.type_desc delivery_status_type_detail
			ON delivery_status_type_detail.type_id = line_item_detail.delivery_status_type_id 
		LEFT JOIN dbo.offer offer
			ON offer.offer_id = line_item.offer_id
		LEFT JOIN core..tix_tran tix ON line_item.order_num = tix.order_num
		WHERE 
			purchase.delete_flag = 0
			AND purchaser.seller_id = @SellerId
			AND (@SupplierId IS NULL OR purchaser.supplier_id = @SupplierId)
			--
			-- purchase_history filters
			--
			AND ( --Account Name
				@AccountName IS NULL OR (
					dbo.f_RemoveCharactersFromString(agency.name, '%[,''.&# ]%') LIKE ('%' + dbo.f_RemoveCharactersFromString(@AccountName, '%[,''.&# ]%') + '%')
				)
			)
			AND ( --Passenger Name
				@Passenger IS NULL OR (
					CONCAT(passenger_person.first_name, ' ', passenger_person.last_name) LIKE ('%' + REPLACE(@Passenger,' ','%') + '%')
					OR CONCAT(passenger_person.last_name, ' ', passenger_person.first_name) LIKE ('%' + REPLACE(@Passenger,' ','%') + '%')
				)
			)
			AND (@AccountId IS NULL OR purchaser.agency_id = @AccountId) --Client ID
			AND (@BookingRef IS NULL OR purchase_ref_memo.memo LIKE ('%' + @BookingRef + '%')) --Booking Reference
			AND (@OrderId IS NULL OR purchase.purchase_history_id LIKE('%' + CAST(@OrderId AS VARCHAR) + '%')) --Order ID
			AND ( --Order Created By
				@CreatorName IS NULL OR (
					CONCAT(dbo.f_RemoveCharactersFromString(purchaser_person.first_name, '%[ '' ]%'), dbo.f_RemoveCharactersFromString(purchaser_person.last_name, '%[ '' ]%')) 
						LIKE CONCAT('%', dbo.f_RemoveCharactersFromString(@CreatorName, '%[,'' ]%'), '%')
					OR
					CONCAT(dbo.f_RemoveCharactersFromString(purchaser_person.last_name, '%[ '' ]%'), dbo.f_RemoveCharactersFromString(purchaser_person.first_name, '%[ '' ]%')) 
						LIKE CONCAT('%', dbo.f_RemoveCharactersFromString(@CreatorName, '%[,'' ]%'), '%')
				)			
			) 
			AND ( --Order Range
				(@OrderRangeBegin IS NULL AND @OrderRangeEnd IS NULL) --Order Range is not provided
				OR ( --Begin and End Order Range provided
					(@OrderRangeBegin IS NOT NULL AND @OrderRangeEnd IS NOT NULL)
					AND CAST(purchase.created AS DATE) BETWEEN CAST(@OrderRangeBegin AS DATE) AND CAST(@OrderRangeEnd AS DATE)
				)
				OR ( --Begin Order Range provided
					(@OrderRangeBegin IS NOT NULL AND @OrderRangeEnd IS NULL)
					AND CAST(purchase.created AS DATE) >= CAST(@OrderRangeBegin AS DATE)
				)
				OR ( --End Order Range provided
					(@OrderRangeBegin IS NULL AND @OrderRangeEnd IS NOT NULL)
					AND CAST(purchase.created AS DATE) < CAST(@OrderRangeEnd AS DATE)
				)
			)
			--
			-- purchase_line_item filters
			--
			AND line_item.delete_flag = 0
			AND (@TransactionId IS NULL OR line_item.tix_tran_num = @TransactionId) --Trans ID
			AND (@LineItemId IS NULL OR line_item.purchase_line_item_id = @LineItemId) --Line Item ID
			AND (@ProductId IS NULL OR EXISTS(
				SELECT 1
				FROM 
					[crm_2].[dbo].[prod_avail] prod_avail  
					INNER JOIN [core].[dbo].[sls_product] product  ON prod_avail.prod_id = product.prod_id AND prod_avail.prod_avail_id = line_item.prod_avail_id 
					AND product.prod_id = @ProductId
				)
			)

			AND (@OurPriceCode IS NULL OR line_item.price_code LIKE @OurPriceCode) --Price Code			
			AND 
			(
                    (@SupplierTransactionId IS NULL OR line_item.order_num = @SupplierTransactionId) --Star Order Number
                OR  (@SupplierTransactionId IS NULL OR line_item_detail.supplier_trans_id LIKE ('%' + @SupplierTransactionId + '%')) --Supplier Trans Id
            )
			--
			-- purchase_line_item_detail filters
			--
			AND (@SupplierPriceCode IS NULL OR line_item_detail.supplier_price_code LIKE @SupplierPriceCode) --Supplier Price Code
			AND (@EventWeekDays IS NULL OR @EventWeekDays LIKE ('%' + DATENAME(WEEKDAY, line_item_detail.product_datetime) + '%')) --Event Day
			AND (@SaleTypeId IS NULL OR line_item_detail.sale_type_id = @SaleTypeId) --Sale Type
			AND (@ProductBaseTypeId IS NULL OR line_item_detail.product_base_type_id = @ProductBaseTypeId) --Product Type
			AND ( --Customer Status
				@CustomerStatusType IS NULL OR (
					( --A range comparison
						@CustomerStatusTypeMax IS NOT NULL AND sale_status_type_detail.type_desc_name BETWEEN @CustomerStatusType AND @CustomerStatusTypeMax
					)
					OR ( --Equal
						((@CustomerStatusComparator IS NULL AND @CustomerStatusTypeMax IS NULL) OR @CustomerStatusComparator = 0 OR @CustomerStatusComparator = 1) 
						AND sale_status_type_detail.type_desc_name = @CustomerStatusCode
					)
					OR (@CustomerStatusComparator = 2 AND sale_status_type_detail.type_desc_name <> @CustomerStatusCode) --Not Equal
					OR (@CustomerStatusComparator = 3 AND sale_status_type_detail.type_desc_name > @CustomerStatusCode) --Greater Than
					OR (@CustomerStatusComparator = 4 AND sale_status_type_detail.type_desc_name < @CustomerStatusCode) --Less Than
				)
			)
			AND ( --Supplier Status
				@SupplierStatusType IS NULL OR (
					( --A range comparison
						@SupplierStatusTypeMax IS NOT NULL AND supplier_status_type_detail.type_desc_name BETWEEN @SupplierStatusType AND @SupplierStatusTypeMax
					)
					OR ( --Equal
						((@SupplierStatusComparator IS NULL AND @SupplierStatusTypeMax IS NULL) OR @SupplierStatusComparator = 0 OR @SupplierStatusComparator = 1) 
						AND supplier_status_type_detail.type_desc_name = @SupplierStatusCode
					)
					OR (@SupplierStatusComparator = 2 AND supplier_status_type_detail.type_desc_name <> @SupplierStatusCode) --Not Equal
					OR (@SupplierStatusComparator = 3 AND supplier_status_type_detail.type_desc_name > @SupplierStatusCode) --Greater Than
					OR (@SupplierStatusComparator = 4 AND supplier_status_type_detail.type_desc_name < @SupplierStatusCode) --Less Than
				)
			)
			AND ( --Delivery Status
				@DeliveryStatusType IS NULL OR (
					( --A range comparison
						@DeliveryStatusTypeMax IS NOT NULL AND delivery_status_type_detail.type_desc_name BETWEEN @DeliveryStatusType AND @DeliveryStatusTypeMax
					)
					OR ( --Equal
						((@DeliveryStatusComparator IS NULL AND @DeliveryStatusTypeMax IS NULL) OR @DeliveryStatusComparator = 0 OR @DeliveryStatusComparator = 1) 
						AND delivery_status_type_detail.type_desc_name = @DeliveryStatusCode
					)
					OR (@DeliveryStatusComparator = 2 AND delivery_status_type_detail.type_desc_name <> @DeliveryStatusCode) --Not Equal
					OR (@DeliveryStatusComparator = 3 AND delivery_status_type_detail.type_desc_name > @DeliveryStatusCode) --Greater Than
					OR (@DeliveryStatusComparator = 4 AND delivery_status_type_detail.type_desc_name < @DeliveryStatusCode) --Less Than
				)
			)
			AND (
				@OrderNotCancelled IS NULL OR @OrderNotCancelled = 0 OR (
					supplier_status_type_detail.type_desc_name > '0' --Supplier Status not cancelled
					AND sale_status_type_detail.type_desc_name > '0' --Customer Status not cancelled
					AND delivery_status_type_detail.type_desc_name > '0' --Delivery Status not cancelled
				)
			)
			AND ( --Event Range
				(@EventRangeBegin IS NULL AND @EventRangeEnd IS NULL) --Event Range is not provided
				OR ( --Begin and End Event Range provided
					(@EventRangeBegin IS NOT NULL AND @EventRangeEnd IS NOT NULL)
					AND CAST(line_item_detail.product_datetime AS DATE) BETWEEN CAST(@EventRangeBegin AS DATE) AND CAST(@EventRangeEnd  AS DATE)
				)
				OR ( --Begin Event Range provided
					(@EventRangeBegin IS NOT NULL AND @EventRangeEnd IS NULL)
					AND CAST(line_item_detail.product_datetime AS DATE) >= CAST(@EventRangeBegin AS DATE)
				)
				OR ( --End Event Range provided
					(@EventRangeBegin IS NULL AND @EventRangeEnd IS NOT NULL)
					AND CAST(line_item_detail.product_datetime AS DATE) < CAST(@EventRangeEnd AS DATE)
				)
			)
			AND ( --Event Time
				(@EventTimeBegin IS NULL AND @EventTimeEnd IS NULL) --Event Range is not provided
				OR ( --Begin and End Event Time Range provided
					(@EventTimeBegin IS NOT NULL AND @EventTimeEnd IS NOT NULL)
					AND CAST(line_item_detail.product_datetime AS time) BETWEEN CAST(@EventTimeBegin AS time) AND CAST(@EventTimeEnd  AS time)
				)
				OR ( --Begin Event Time Range provided
					(@EventTimeBegin IS NOT NULL AND @EventTimeEnd IS NULL)
					AND CAST(line_item_detail.product_datetime AS time) = CAST(@EventTimeBegin AS time)
				)
				OR ( --End Event Time Range provided
					(@EventTimeBegin IS NULL AND @EventTimeEnd IS NOT NULL)
					AND CAST(line_item_detail.product_datetime AS time) < CAST(@EventTimeEnd AS time)
					)
					)
			AND (@City IS NULL OR EXISTS(
				SELECT TOP 1  * 
				FROM 
					[crm_2].[dbo].[prod_avail] prod_avail  
					INNER JOIN [core].[dbo].[sls_product] product  ON prod_avail.prod_id = product.prod_id AND prod_avail.prod_avail_id = line_item.prod_avail_id 
					INNER JOIN [core].[dbo].sls_city city ON product.city_code = city.city_id 
				WHERE 
					[city].[desc] = @CITY
				)
			)

			AND ( --Product Status
				@CheckProductActiveStatus IS NULL OR @CheckProductActiveStatus = 0
				OR (
					@CheckProductActiveStatus = 1 
					AND (@IsProductActive IS NULL OR offer.active_flg = @IsProductActive)
				)
			) 
			--
			-- Method of Delivery
			--
			AND ( --Method of Delivery
				@MethodOfDeliveryCode IS NULL OR (
					0 = ( --Count the number of prod avails that DO NOT match the preferred MOD
						SELECT COUNT(*)
						FROM (
							SELECT pli.*,tix.[mod]
								FROM dbo.purchase_line_item pli
								JOIN core.dbo.tix_tran tix ON pli.order_num = tix.order_num
								WHERE pli.purchase_line_item_id = line_item.purchase_line_item_id
								) AS all_prod_avails
								WHERE all_prod_avails.[mod] IS NULL OR all_prod_avails.[mod] NOT LIKE @MethodOfDeliveryCode
					)
				) 
			)
			AND
			(@SalesVehicleId IS NULL OR line_item.sales_vehicle_id = @SalesVehicleId)
	) filtered_purchase
	LEFT JOIN dbo.person
		ON person.person_id = filtered_purchase.received_by_person_id

	OUTER APPLY (SELECT * FROM dbo.ufn_get_memo_by_history_id(filtered_purchase.purchase_history_id, 1190)) AS memo

	INNER JOIN dbo.purchaser
		ON purchaser.purchaser_id = filtered_purchase.purchaser_id AND purchaser.agency_id IS NOT NULL
    INNER JOIN dbo.person purchaser_person
			ON purchaser_person.person_id = purchaser.person_id	
	INNER JOIN dbo.agency
		ON agency.agency_id = purchaser.agency_id		
	INNER JOIN dbo.purchase_line_item
		ON purchase_line_item.purchase_history_id = filtered_purchase.purchase_history_id
	INNER JOIN dbo.purchase_line_item_detail
		ON purchase_line_item_detail.purchase_line_item_id = purchase_line_item.purchase_line_item_id
	LEFT JOIN dbo.offer offer
		ON offer.offer_id = purchase_line_item.offer_id
	LEFT JOIN dbo.person passenger_person
			ON passenger_person.person_id = filtered_purchase.received_by_person_id
	--New Code
	WHERE @MethodOfDeliveryCode IS NULL OR filtered_purchase.mod LIKE @MethodOfDeliveryCode
	--End New Code
END



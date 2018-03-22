/*
 * These are some independent samples of methods written in C#
 * that are currently deployed live to a high-volume production environment.
 * The following code is servicing thousands of visitors each day.
 */

[HttpPost]
public IEnumerable<Offer> GetOffers(OfferFilter input)
{
	var validationErrorMessage = ValidateAndGetErrorMessage("Some invalid information was provided");
	if (input == null || !string.IsNullOrWhiteSpace(validationErrorMessage))
	{
		return new List<Offer>();
	}
	SetWholesaleUserValues();

	try
	{
		var parsedOffers = new List<Offer>();
		var starNetFITOffers = GetWholesaleOfferObj(true);

		var starNetGroupOffers = GetWholesaleOfferObj(false);
		var promoOnly = input.PromoCodeOnly.HasValue ? input.PromoCodeOnly.Value : false;
		if (!promoOnly)
		{
			var retrievedFITOffers = starNetFITOffers.GetPublicWholesaleOffers(SellerId, 0);
			var parsedFITOffers = ParseOfferCollection(retrievedFITOffers, input.EligibilityGroupIds, input.SelectedAccountId);

			var retrivedGroupOffers = starNetGroupOffers.GetPublicWholesaleOffers(SellerId, 0);
			var parsedGroupOFfers = ParseOfferCollection(retrivedGroupOffers, input.EligibilityGroupIds, input.SelectedAccountId);

			parsedOffers.AddRange(parsedFITOffers);
			parsedOffers.AddRange(parsedGroupOFfers);
		}
		
		//Fetch promotional offers if a promo code is provided.
		if (!string.IsNullOrWhiteSpace(input.PromoCode))
		{
			var promotionalOffers = starNetFITOffers.GetPublicWholesaleOffers(SellerId, 0, null, null, null, input.PromoCode, null, null, "", null, null, null);
			parsedOffers = parsedOffers.Union(ParseOfferCollection(promotionalOffers, input.EligibilityGroupIds, input.SelectedAccountId));
		}

		return parsedOffers;
	}
	catch (Exception ex)
	{
		CRMDataServiceLogger.LogOnly(ex.Message);
		return new List<Offer>();
	}
}


protected string ValidateAndGetErrorMessage(string errorMessagePrefix)
{
	//If all the Model data is valid, do not return an error message.
	if (ModelState.IsValid) return null;

	var errorMessage = "";
	if (!string.IsNullOrWhiteSpace(errorMessagePrefix))
	{
		errorMessage = errorMessagePrefix + ": ";
	}

	//Return an error message constructed from all validation errors.
	return errorMessage
			+ string.Join(" - ", 
				ModelState.Values.SelectMany(s => s.Errors)
				.Select(err => err?.ErrorMessage)
				.Union(ModelState.Values.SelectMany(s => s.Errors)
					.Select(err => err?.Exception?.Message)
				)
				.Where(message => !string.IsNullOrWhiteSpace(message))
			);
}

public IEnumerable<TimeCategoryInfo> GetTimeCategoryInfo(int? productId, int? accountId, DateTime? offerDate)
{
	var activeOffers = _commonHelper.GetEligibleActiveOffersForProduct(productId, accountId);
	var firstActiveOffer = activeOffers.FirstOrDefault();

	if(firstActiveOffer == null)
	{
		return new List<TimeCategoryInfo>();
	}

	_wholesaleProdAvailInfoByOfferColl.Clear();
	_wholesaleProdAvailInfoByOfferColl.Fill(firstActiveOffer.OfferId, SellerId, SupplierId, OperatorUserID, offerDate);

	//Group the times into categories.
	var timeCategoryInfo = _wholesaleProdAvailInfoByOfferColl.Where(
		o => (productId == null || o.ProductId == productId)
	)
	.GroupBy(
		m => new { m.OfferId, m.PackageId, m.ProdAvailId, m.ProductId },
		m => new TimeCategory
		{
			PerfType = m.PerfType,
			PerfTime = m.PerfTime,
			Category = m.TimeCategory
		},
		(key, ungroupedCategories) => new TimeCategoryInfo
		{
			OfferId = key.OfferId,
			PackageId = key.PackageId,
			ProdAvailId = key.ProdAvailId,
			ProductId = key.ProductId,
			TimeCategories = ungroupedCategories.GroupBy(c => c.Category,
				c => c,
				(catKey, categories) => new
				{
					TimeCategoryName = catKey,
					TimeCategories = categories
				}
			)
			.ToDictionary(k => k.TimeCategoryName, v => v.TimeCategories)
		}
	);

	return timeCategoryInfo;
}

//Overwriting the RawRecord GetHashCode() method was not an option.
public static int GetRawRecordSignature(wholesale_fetch_seller_code_product_price priceRecord)
{
	unchecked
	{
		var hash = 727;

		hash = hash * 13 + GetTimeSectionOfDay(priceRecord).GetHashCode();
		hash = hash * 17 + priceRecord.PriceCode.GetHashCode();
		hash = hash * 23 + priceRecord.RegularPrice.GetHashCode();
		hash = hash * 29 + priceRecord.BasePrice.GetHashCode();
		hash = hash * 31 + priceRecord.TicketServiceCharge.GetHashCode();
		hash = hash * 37 + priceRecord.OperShare.GetHashCode();
		hash = hash * 41 + priceRecord.AncillaryTotal.GetHashCode();
		hash = hash * 43 + priceRecord.TaxTotal.GetHashCode();

		return hash;
	}
}

private IEnumerable<WholesalePerformanceTimeBlock> ParseTimeBlocksFromWeek(WeekSignature week)
{
	var wholesaleTimeBlocks = new List<WholesalePerformanceTimeBlock>();

	//Group all weekly price records by day into a dictionary where the key is the date.
	var weekPerformancesGroupedByDay = week.WeeklyPrices.GroupBy(
		wp => wp.PerformanceDate,
		wp => wp,
		(date, dayPrices) => new
		{
			Date = date,
			DayPrices = GroupConsecutivePerformanceTimePrices(dayPrices, date)
		})
		.ToDictionary(kvp => kvp.Date, kvp => kvp.DayPrices);

	/*
	* Map each TimeSectionSignature (the prices in a consecutive group of Performance Times in 
	* a single day) into a dictionary, where the key is a unique TimeSectionSignature, and the 
	* value is a collection of the days that contain the TimeSectionSignature.
	* 
	* Note that two Time Sections with identical properties (performance times, price codes, and prices)
	* are considered the same even if they are on different days. Their signatures are equal.
	*/
	var daysByTimeSectionSignature = new Dictionary<TimeSectionSignature, HashSet<DateTime>>();
	foreach (var timeSectionsForDayKvp in weekPerformancesGroupedByDay)
	{
		var timeSectionSignatures = timeSectionsForDayKvp.Value;

		var timeSectionsDate = timeSectionsForDayKvp.Key.GetValueOrDefault();

		if (timeSectionsDate != null)
		{
			foreach (var timeBlock in timeSectionSignatures)
			{
				if (!daysByTimeSectionSignature.ContainsKey(timeBlock))
				{
					daysByTimeSectionSignature.Add(timeBlock, new HashSet<DateTime>());
				}

				daysByTimeSectionSignature[timeBlock].Add(timeSectionsDate);
			}
		}
	}

	//Create a time block for each distinct time section signature.
	foreach (var timeSectionSignatureKvp in daysByTimeSectionSignature)
	{
		var timeSectionSignature = timeSectionSignatureKvp.Key;
		var productPriceRecords = timeSectionSignature.GetRecords();
		var activeEligibleOffers = timeSectionSignature.GetActiveEligibleOffers();

		var timeStart = productPriceRecords.Min(p => p.PerformanceTime);
		var timeEnd = productPriceRecords.Max(p => p.PerformanceTime);
		var daysOfWeek = timeSectionSignatureKvp.Value.Distinct().Select(d => d.DayOfWeek.ToString());

		/*
		 * Merge the Price Record collection with the Eligible Offers collection.
		 * Convert each merged record into a WholesalePerformancePriceBlock
		 */
		var priceBlocks = activeEligibleOffers.SelectMany(
			offer =>
				productPriceRecords.Select(
					record => new WholesalePerformancePriceBlock
					{
						PriceCode = record.PriceCode,
						Area = record.AreaName,
						RegularPrice = record.RegularPrice.GetValueOrDefault(),
						BasePrice = record.BasePrice.GetValueOrDefault(),
						TicketServiceCharge = record.TicketServiceCharge.GetValueOrDefault(),
						OperShare = record.OperShare.GetValueOrDefault(),
						AncillaryTotal = record.AncillaryTotal.GetValueOrDefault(),
						TaxTotal = record.TaxTotal.GetValueOrDefault(),
						OfferName = offer.OfferName
					}
				)
		)
		.Distinct();                

		var dateInSection = productPriceRecords.First().PerformanceDate;

		wholesaleTimeBlocks.Add(new WholesalePerformanceTimeBlock
		{
			TimeStart = timeStart.GetValueOrDefault(),
			TimeEnd = timeEnd.GetValueOrDefault(),
			DaysOfWeek = daysOfWeek,
			TimeCategoryInfo = GetTimeCategoryInfoIfAttraction(dateInSection),
			PriceBlocks = priceBlocks
		});
	}

	return wholesaleTimeBlocks;
}
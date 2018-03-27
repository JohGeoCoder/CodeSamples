/*
 * The problem we needed to solve was the implementation of CSRF Tokens in 
 * a stand-alone javascript application.
 * 
 * For each ajax call, we first needed to poll the server for a CSRF token.
 * When returned, we would use that token to make the target ajax call.
 * 
 * This function wraps the jQuery ajax call with the CSRF call, effectively
 * making the CSRF call DRY.
 * 
 * Examples of this functions use are below. The context of this code is a KnockoutJS application.
 */
var _csrfAjax = function(urlInfo, requestData){
	var requestUrl = '';
	var csrfUrl = '';
	
	/*
	 * Determine the type of URL info being provided.
	 */
	if(typeof urlInfo === 'object'){
		if(urlInfo.hasOwnProperty('Url')) requestUrl = urlInfo.Url;
		if(urlInfo.hasOwnProperty('CsrfUrl')) csrfUrl = urlInfo.CsrfUrl;
	} else if(typeof urlInfo === 'string'){
		requestUrl = urlInfo;
	}

	var securedRequest = null;
	
	/*
	 * If a CSRF Url is provided, poll the CSRF Token before the desired call.
	 * Otherwise, skip directly to the desired call.
	 */
	if(csrfUrl){
		var csrfRequest = $.ajax(csrfUrl, {
			dataType: 'json',
			method: 'post'
		});
		
		/*
		 * Generate the secured request using the CSRF request.
		 */
		securedRequest = csrfRequest
			.then(function(csrfData){
				var syncToken = '';

				if(csrfData.hasOwnProperty('Error')){
					console.log(csrfData.Error);
				}
				else if(csrfData.hasOwnProperty('SyncToken')){
					syncToken = csrfData.SyncToken;
				}

				if(syncToken){
					requestData.SyncToken = syncToken;
				}

				//Stringify the request data because that is what the Proxy controls expect.
				//It won't properly bind if sent as an object.
				var stringifiedRequestData = JSON.stringify(requestData);
				
				/*
				 * The secured request returns a promise for the desired call that 
				 * can later be resolved in the application using .then, .done, .fail, etc.
				 */
				return $.ajax(requestUrl, {
					data: stringifiedRequestData,
					dataType: 'json',
					method: 'post'
				});
			})
			.fail(function(jqXHR, textStatus, errorThrown){
				var deferred = new $.Deferred;
				return deferred.reject('CSRF token query failed.');
			});
	} else {
		
		//Stringify the request data because that is what the Proxy controls expect.
		//It won't properly bind if sent as an object.
		var stringifiedRequestData = JSON.stringify(requestData);
		
		/*
		 * In the case when a CSRF Url is not provided, the standard request returns 
		 * a promise for the desired call that can later be resolved in the application 
		 * using .then, .done, .fail, etc.
		 */
		securedRequest = $.ajax(requestUrl, {
			data: stringifiedRequestData,
			dataType: 'json',
			method: 'post'
		});
	}


	return securedRequest;
};

/*
 * An example of the CSRF ajax call.
 */
OrderEntry.Helpers.CsrfAjax(OrderEntry.Endpoints.GetAccountAndContact, getAccountAndContactData)
	.done(function(data){
		if(data){
			self.SelectedContact.copyDataFromContact(data.Contact);
			self.SelectedOrganization.copyDataFromAccount(data.Account);

			if(data.Account){
				self.FetchOffers(null, data.Account.EligibilityGroups, self.SelectedOrganization.AccountId());
			}
		} else{
			console.log("GetAccountAndContact: null return data");
		}            
	})
	.fail(function(jqXHR, textStatus, errorThrown){
		if (!!console) console.log("GetAccountAndContact: failure");
	});

/*
 * An example of the CSRF ajax call.
 */
OrderEntry.Helpers.CsrfAjax(OrderEntry.Endpoints.GetOrderReceipt, getFormTemplateData)
	.done(function(data){
		if(data && !data.Success){ 
			var errorMessage = data.ExternalMessages && data.ExternalMessages.length > 0 ? data.ExternalMessages.join(' - ') : '';
			alert("Could not retrieve receipt: " + errorMessage);
			return;
		}
		$(OrderEntry.Selectors.FormPrintContainer).html(data.RenderedHtml)
		OrderEntry.Helpers.printElement(OrderEntry.Selectors.FormPrintContainer);
	})
	.fail(function(jqXHR, textStatus, errorThrown){
		alert(errorThrown);
	});

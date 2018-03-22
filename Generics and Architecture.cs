///
/// The challenge was to create a stand-alone service that creates PDF documents,
/// Renders Razor templates, and sends documents to emails. The templates of all
/// the formats are stored in a database, so they can be updated without re-deploying
/// the application.
///
public static FormProcessingResponse ProcessGenericForm<T>(T formData, FormActivityType activityType, CrmServiceData serviceData) where T : BaseFormModel
{
	switch (activityType)
	{
		case FormActivityType.FormPrinted:
			return new GenericFormHtmlProcessor<T>(serviceData, formData, activityType).Process();
		case FormActivityType.FormEmailed:
			return new GenericFormEmailProcessor<T>(serviceData, formData, activityType).Process();
		case FormActivityType.FormDownloaded:
			return new GenericFormDownloadProcessor<T>(serviceData, formData, activityType).Process();
		default:
			return new FormProcessingResponse()
			{
				Success = false,
				InternalMessages = new List<string> { "Invalid Action Type" },
				ExternalMessages = new List<string> { "Something went wrong" }
			};
	}
}

///
/// An implementation of the Generic Form Processor that renders a PDF
/// from the Form Model and returns the result for downloading.
///
public class GenericFormDownloadProcessor<T> : GenericFormProcessor<T> where T : BaseFormModel
{
	public GenericFormDownloadProcessor(CrmServiceData serviceData, T formModel, FormActivityType activityType)
		: base(serviceData, formModel, activityType) {}

	public override FormProcessingResponse Process()
	{
		FormProcessingResponse result = null;
		if (Template != null)
		{
			var razorRenderResponse = DocumentTemplateRenderer.RenderRazorViewToString(Template.Template, FormModel);
			if (razorRenderResponse.Success)
			{
				var formGenerationResponse = HTMLPDFGenerator.GetPdf(razorRenderResponse.RenderedDocument);

				if (formGenerationResponse.Success)
				{
					result = new FormProcessingResponse
					{
						Success = true,
						RenderedHtml = razorRenderResponse.RenderedDocument,
						FormActivityType = ActivityType,
						TemplateId = Template.DocumentTemplateId,
						PdfForm = formGenerationResponse.PdfForm
					};
				}
				else
				{
					result = new FormProcessingResponse
					{
						Success = false,
						InternalMessages = new List<string> { formGenerationResponse.InternalMessage },
						ExternalMessages = new List<string> { formGenerationResponse.ExternalMessage },
						ErrorCodes = new List<ErrorCode> { new ErrorCode { Code = formGenerationResponse.ErrorCode } }
					};
				}
			}
			else
			{
				result = new FormProcessingResponse
				{
					Success = false,
					ExternalMessages = new List<string> { "An error occured with your document." },
					InternalMessages = new List<string> { razorRenderResponse.InternalMessage }
				};
			}
		}

		return result;
	}
}

///
/// The abstract base class for working with form templates.
///
public abstract class GenericFormProcessor<T> where T : BaseFormModel
{
	public CrmServiceData ServiceData { get; set; }
	public DocumentTemplate Template { get; set; }
	public FormActivityType ActivityType { get; set; }
	public T FormModel { get; set; }

	protected GenericFormProcessor(CrmServiceData serviceData, T formData, FormActivityType activityType)
	{
		ServiceData = serviceData;
		FormModel = formData;
		ActivityType = activityType;

		//Retrieve the template details from the database.
		var templateCollection = new DocumentTemplateCollection(serviceData.UserId, serviceData.ClientId, serviceData.OperCode);
		templateCollection.FillBySellerId(serviceData.SellerId);

		var template = templateCollection.FirstOrDefault(t => t.SupplierId == serviceData.SupplierId && t.TemplateTypeId == (int)formData.TemplateType);
		Template = template;
	}

	public abstract FormProcessingResponse Process();
}


///
/// Sample use of the CRM Forms Service
/// Abstraction really pays off
///
public void SendEmail()
{
	//...
	var priceListModel = new PriceListFormsModel(recipientEmail)
	{
		DateBlocks = priceListDisplayData.DateBlocks,
		Agency = priceListDisplayData.Agency,
		Product = priceListDisplayData.Product,
		WholesaleSalesType = wholesaleSalesType
	};

	var serviceData = new CrmServiceData
	{
		UserId = BrandConfig.OperatorOpCode,
		ClientId = BrandConfig.ClientId,
		OperCode = BrandConfig.OperCode,
		SellerId = BrandConfig.SellerId,
		SupplierId = BrandConfig.SupplierId
	};
	
	var formEmail = CRMFormsService.ProcessGenericForm(priceListModel, FormActivityType.FormEmailed, serviceData);
	//...
}

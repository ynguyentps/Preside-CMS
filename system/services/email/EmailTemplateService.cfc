/**
 * @singleton      true
 * @presideService true
 * @autodoc        true
 *
 */
component {

	/**
	 * @systemEmailTemplateService.inject systemEmailTemplateService
	 * @emailRecipientTypeService.inject  emailRecipientTypeService
	 * @emailLayoutService.inject         emailLayoutService
	 *
	 */
	public any function init(
		  required any systemEmailTemplateService
		, required any emailRecipientTypeService
		, required any emailLayoutService
	) {
		_setSystemEmailTemplateService( arguments.systemEmailTemplateService );
		_setEmailRecipientTypeService( arguments.emailRecipientTypeService );
		_setEmailLayoutService( arguments.emailLayoutService );

		_ensureSystemTemplatesHaveDbEntries();

		return this;
	}

// PUBLIC API
	/**
	 * Prepares an email message ready for sending (returns a struct with
	 * information about the message)
	 *
	 * @autodoc true
	 * @template.hint       The ID of the template to send
	 * @args.hint           Structure of args to provide email specific information about the send (i.e. userId of web user to send to, etc.)
	 * @to.hint             Optional array of addresses to send the email to (leave empty should the recipient type for the template be able to calculate this for you)
	 * @cc.hint             Optional array of addresses to cc in to the email
	 * @bcc.hint            Optional array of addresses to bcc in to the email
	 * @parameters.hint     Optional struct of variables for use in content token substitution in subject and body
	 * @messageHeaders.hint Optional struct of email message headers to set
	 */
	public struct function prepareMessage(
		  required string template
		, required struct args
		,          array  to             = []
		,          array  cc             = []
		,          array  bcc            = []
		,          struct parameters     = {}
		,          struct messageHeaders = {}
	) {

		var messageTemplate  = getTemplate( arguments.template );

		if ( messageTemplate.isEmpty() ) {
			throw( type="preside.emailtemplateservice.missing.template", message="The email template, [#arguments.template#], could not be found." );
		}

		var params = Duplicate( arguments.parameters );
		params.append( prepareParameters(
			  template      = arguments.template
			, recipientType = messageTemplate.recipient_type
			, args          = arguments.args
		) );

		var message = {
			  subject = replaceParameterTokens( messageTemplate.subject, params, "text" )
			, from    = messageTemplate.from_address
			, to      = arguments.to
			, cc      = arguments.cc
			, bcc     = arguments.bcc
			, params  = arguments.messageHeaders
		};

		if ( !message.to.len() ) {
			message.to = [ _getEmailRecipientTypeService().getToAddress( recipientType=messageTemplate.recipient_type, args=arguments.args ) ];
		}

		if ( !message.from.len() ) {
			message.from = $getPresideSetting( "email", "default_from_address" );
		}

		// // TODO attachments stuffz from editorial template
		// message.attachments = [];
		// var isSystemTemplate = _getSystemEmailTemplateService().templateExists( arguments.template );
		// if ( isSystemTemplate ) {
		// 	message.attachments.append( _getSystemEmailTemplateService().prepareAttachments(
		// 		  template = arguments.template
		// 		, args     = arguments.args
		// 	), true );
		// }

		message.textBody = _getEmailLayoutService().renderLayout(
			  layout        = messageTemplate.layout
			, emailTemplate = arguments.template
			, type          = "text"
			, subject       = message.subject
			, body          = replaceParameterTokens( messageTemplate.text_body, params, "text" )
		);
		message.htmlBody = _getEmailLayoutService().renderLayout(
			  layout        = messageTemplate.layout
			, emailTemplate = arguments.template
			, type          = "html"
			, subject       = message.subject
			, body          = replaceParameterTokens( messageTemplate.html_body, params, "html" )
		);

		return message;
	}

	/**
	 * Inserts or updates the given email template
	 *
	 * @autodoc  true
	 * @template Struct containing fields to save
	 * @id       Optional ID of the template to save (if empty, assumes its a new template)
	 *
	 */
	public string function saveTemplate(
		  required struct template
		,          string id       = ""
	) {
		transaction {
			if ( Len( Trim( arguments.id ) ) ) {
				var updated = $getPresideObject( "email_template" ).updateData(
					  id   = arguments.id
					, data = arguments.template
				);

				if ( updated ) {
					return arguments.id;
				}

				arguments.template.id = arguments.id;

			}
			var newId = $getPresideObject( "email_template" ).insertData( data=arguments.template );

			return arguments.template.id ?: newId;
		}
	}

	/**
	 * Returns whether or not the given template exists in the database
	 *
	 * @autodoc true
	 * @id.hint ID of the template to check
	 */
	public boolean function templateExists( required string id ) {
		return $getPresideObject( "email_template" ).dataExists( id=arguments.id );
	}

	/**
	 * Returns the saved template from the database
	 *
	 * @autodoc true
	 * @id.hint ID of the template to get
	 *
	 */
	public struct function getTemplate( required string id ){
		var template = $getPresideObject( "email_template" ).selectData( id=arguments.id );

		for( var t in template ) {
			return t;
		}

		return {};
	}

	/**
	 * Replaces parameter tokens in strings (subject, body) with
	 * passed in values.
	 *
	 * @autodoc true
	 * @text    The raw text that contains the parameter tokens
	 * @params  A struct of params. Each param can either be a simple value or a struct with simple values for `html` and `text` keys
	 * @type    Either 'text' or 'html'
	 *
	 */
	public string function replaceParameterTokens(
		  required string text
		, required struct params
		, required string type
	) {
		arguments.type = arguments.type == "text" ? "text" : "html";
		var replaced = arguments.text;

		for( var paramName in arguments.params ) {
			var token = "${#paramName#}";
			var value = IsSimpleValue( arguments.params[ paramName ] ) ? arguments.params[ paramName ] : ( arguments.params[ paramName ][ arguments.type ] ?: "" );

			replaced = replaced.replaceNoCase( token, value, "all" );
		}

		return replaced;
	}

	/**
	 * Prepares params (for use in replacing tokens in subject and body)
	 * for the given email template, recipient type and sending args.
	 *
	 * @autodoc       true
	 * @template      ID of the template of the email that is being prepared
	 * @recipientType ID of the recipient type of the email that is being prepared
	 * @args          Structure of variables that are being used to send / prepare the email
	 */
	public struct function prepareParameters(
		  required string template
		, required string recipientType
		, required struct args
	) {
		var params = _getEmailRecipientTypeService().prepareParameters(
			  recipientType = arguments.recipientType
			, args          = arguments.args
		);
		if ( _getSystemEmailTemplateService().templateExists( arguments.template ) ) {
			params.append( _getSystemEmailTemplateService().prepareParameters(
				  template = arguments.template
				, args     = arguments.args
			) );
		}

		return params;
	}

// PRIVATE HELPERS
	private void function _ensureSystemTemplatesHaveDbEntries() {
		var sysTemplateService = _getSystemEmailTemplateService();
		var systemTemplates    = sysTemplateService.listTemplates();

		for( var template in systemTemplates ) {
			if ( !templateExists( template.id ) ) {
				saveTemplate( id=template.id, template={
					  name           = template.title
					, layout         = sysTemplateService.getDefaultLayout( template.id )
					, subject        = sysTemplateService.getDefaultSubject( template.id )
					, html_body      = sysTemplateService.getDefaultHtmlBody( template.id )
					, text_body      = sysTemplateService.getDefaultTextBody( template.id )
					, recipient_type = sysTemplateService.getRecipientType( template.id )
				} );
			}
		}
	}

// GETTERS AND SETTERS
	private any function _getSystemEmailTemplateService() {
		return _systemEmailTemplateService;
	}
	private void function _setSystemEmailTemplateService( required any systemEmailTemplateService ) {
		_systemEmailTemplateService = arguments.systemEmailTemplateService;
	}

	private any function _getEmailRecipientTypeService() {
		return _emailRecipientTypeService;
	}
	private void function _setEmailRecipientTypeService( required any emailRecipientTypeService ) {
		_emailRecipientTypeService = arguments.emailRecipientTypeService;
	}

	private any function _getEmailLayoutService() {
		return _emailLayoutService;
	}
	private void function _setEmailLayoutService( required any emailLayoutService ) {
		_emailLayoutService = arguments.emailLayoutService;
	}
}
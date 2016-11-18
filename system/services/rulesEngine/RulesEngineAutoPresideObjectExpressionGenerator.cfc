/**
 * Service that provides logic for automatically generating rules
 * engine expressions from the preside object library.
 *
 * @autodoc        true
 * @singleton      true
 * @presideService true
 *
 */
component {

// CONSTRUCTOR
	/**
	 * @rulesEngineExpressionService.inject rulesEngineExpressionService
	 * @rulesEngineContextService.inject    rulesEngineContextService
	 *
	 */
	public any function init(
		  required any rulesEngineExpressionService
		, required any rulesEngineContextService
	) {
		_setRulesEngineExpressionService( arguments.rulesEngineExpressionService );
		_setRulesEngineContextService( arguments.rulesEngineContextService );

		return this;
	}


	public void function generateAndRegisterAutoExpressions() {
		var objects = $getPresideObjectService().listObjects();

		for( var objectName in objects ) {
			var properties = $getPresideObjectService().getObjectProperties( objectName );
			for( var propName in properties ) {
				if ( !propName.startsWith( "_" ) ) {
					var expressions = generateExpressionsForProperty( objectName, properties[ propName ] );
					for( var expression in expressions ) {
						_getRulesEngineExpressionService().addExpression( argumentCollection=expression );
					}
					if ( expressions.len() ) {
						_getRulesEngineContextService().addContext( id="presideobject_" & objectName, object=objectName );
					}
				}
			}

		}
	}

// PUBLIC API
	/**
	 * Generates all the expressions for a given property (does the hard work)
	 *
	 */
	public array function generateExpressionsForProperty(
		  required string objectName
		, required struct propertyDefinition
	) {
		var isRequired   = IsBoolean( propertyDefinition.required ?: "" ) && propertyDefinition.required;
		var propType     = propertyDefinition.type ?: "string";
		var relationship = propertyDefinition.relationship ?: "";
		var expressions  = [];

		if ( !isRequired && !( [ "many-to-many", "one-to-many" ] ).findNoCase( relationship ) ) {
			switch( propType ) {
				case "string":
				case "numeric":
					expressions.append( _createIsEmptyExpression( objectName, propertyDefinition.name ) );
				break;
				default:
					expressions.append( _createIsSetExpression( objectName, propertyDefinition.name ) );
			}
		}

		return expressions;
	}

// PRIVATE HELPERS
	private struct function _createIsEmptyExpression( required string objectName, required string propertyName ) {
		var expression  = _getCommonExpressionDefinition( objectName, propertyName );

		expression.append( {
			  id                = "presideobject_propertyIsEmpty_#arguments.propertyName#"
			, fields            = { _is={ fieldType="boolean", variety="isIsNot", default=true, required=false } }
			, expressionHandler = "rules.dynamic.presideObjectExpressions.PropertyIsNull.evaluateExpression"
			, filterHandler     = "rules.dynamic.presideObjectExpressions.PropertyIsNull.prepareFilters"
			, labelHandler      = "rules.dynamic.presideObjectExpressions.PropertyIsNull.getLabel"
			, textHandler       = "rules.dynamic.presideObjectExpressions.PropertyIsNull.getText"
		} );

		expression.expressionHandlerArgs.variety = "isEmpty";
		expression.filterHandlerArgs.variety     = "isEmpty";
		expression.labelHandlerArgs.variety      = "isEmpty";
		expression.textHandlerArgs.variety       = "isEmpty";

		return expression;
	}

	private struct function _createIsSetExpression( required string objectName, required string propertyName ) {
		var expression  = _getCommonExpressionDefinition( objectName, propertyName );

		expression.append( {
			  id                = "presideobject_propertyIsSet_#arguments.propertyName#"
			, fields            = { _is={ fieldType="boolean", variety="isIsNot", default=true, required=false } }
			, expressionHandler = "rules.dynamic.presideObjectExpressions.PropertyIsNull.evaluateExpression"
			, filterHandler     = "rules.dynamic.presideObjectExpressions.PropertyIsNull.prepareFilters"
			, labelHandler      = "rules.dynamic.presideObjectExpressions.PropertyIsNull.getLabel"
			, textHandler       = "rules.dynamic.presideObjectExpressions.PropertyIsNull.getText"
		} );

		expression.expressionHandlerArgs.variety = "isSet";
		expression.filterHandlerArgs.variety     = "isSet";
		expression.labelHandlerArgs.variety      = "isSet";
		expression.textHandlerArgs.variety       = "isSet";

		return expression;
	}

	private struct function _getCommonExpressionDefinition( required string objectName, required string propertyName ){
		var i18nBaseUri = $getPresideObjectService().getResourceBundleUriRoot( objectName );

		return {
			  contexts              = [ "presideobject_" & objectName ]
			, filterObjects         = [ objectName ]
			, expressionHandlerArgs = { propertyName=propertyName }
			, filterHandlerArgs     = { propertyName=propertyName }
			, labelHandlerArgs      = { propertyName=propertyName }
			, textHandlerArgs       = { propertyName=propertyName }
		};
	}

// GETTERS AND SETTERS
	private any function _getRulesEngineExpressionService() {
		return _rulesEngineExpressionService;
	}
	private void function _setRulesEngineExpressionService( required any rulesEngineExpressionService ) {
		_rulesEngineExpressionService = arguments.rulesEngineExpressionService;
	}

	private any function _getRulesEngineContextService() {
		return _rulesEngineContextService;
	}
	private void function _setRulesEngineContextService( required any rulesEngineContextService ) {
		_rulesEngineContextService = arguments.rulesEngineContextService;
	}
}
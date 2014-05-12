component extends="coldbox.system.web.Controller" output=false {

	public any function init() output=false {
		super.init( argumentCollection = arguments );

		services.handlerService = new preside.system.coldboxModifications.services.HandlerService( this );
	}

	public boolean function handlerExists( required string event ) output=false {
		var cache      = getCacheBox().getCache( "default" );
		var handlerSvc = "";
		var handler    = "";
		var action     = ListLast( arguments.event, "." );
		var cacheKey   = "handler exists: " & arguments.event;
		var exists     = cache.get( cacheKey );

		if ( not IsNull( exists ) ) {
			return exists;
		}

		try {
			handlerSvc = getHandlerService();
			handler = handlerSvc.getRegisteredHandler( event=arguments.event );
			if ( handler.getViewDispatch() ) {
				cache.set( cacheKey, false );
				return false;
			}
			handler = handlerSvc.getHandler( handler, _getRequestContext() );
			handler = GetMetaData( handler );
			if ( Right( handler.fullname ?: "", Len( arguments.event ) ) eq arguments.event ) {
				action = getSetting( name="EventAction", fwSetting=true, defaultValue="index" );
			}
			exists = _actionExistsInHandler( handler, action );
			cache.set( cacheKey, exists );

			return exists;

		} catch( "HandlerService.EventHandlerNotRegisteredException" e ) {
			cache.set( cacheKey, false );
			return false;
		}
	}

	public boolean function viewExists( required string view ) output=false {
		var cache      = getCacheBox().getCache( "default" );
		var cacheKey   = "view exists: " & arguments.view;
		var exists     = cache.get( cacheKey );
		var targetView = "";

		if ( not IsNull( exists ) ) {
			return exists;
		}

		targetView = getPlugin( "renderer" ).locateView( ListChangeDelims( arguments.view, "/", "." ) );
		exists     = Len( Trim( targetView ) ) and FileExists( ExpandPath( targetView & ".cfm" ) );

		cache.set( cacheKey, exists );

		return exists;
	}

	public boolean function viewletExists( required string event ) output=false {
		return handlerExists( arguments.event ) or viewExists( arguments.event );
	}

	public any function renderViewlet( required string event, struct args={}, boolean private=true, boolean prepostExempt=true  ) output=false {
		var result        = "";
		var view          = "";
		var handler       = arguments.event;
		var defaultAction = getSetting( name="EventAction", fwSetting=true, defaultValue="index" );

		if ( not handlerExists( handler ) ) {
			handler = ListAppend( handler, defaultAction, "." )
		}

		if ( handlerExists( handler ) ) {
			return runEvent(
				  event          = handler
				, prepostExempt  = arguments.prepostExempt
				, private        = arguments.private
				, eventArguments = { viewletArgs = arguments.args }
			);
		}

		view = ListChangeDelims( arguments.event, "/", "." );
		if ( not viewExists( view ) ) {
			view = ListAppend( view, defaultAction, "/" );
		}
		return getPlugin( "renderer" ).renderView(
			  view = view
			, args = arguments.args
		);
	}

// private helpers
	private any function _getRequestContext() output=false {
		return getRequestService().requestCapture();
	}

	private boolean function _actionExistsInHandler( required struct handlerMeta, required string action ) output=false {
		if ( StructKeyExists( arguments.handlerMeta, "extends" ) and _actionExistsInHandler( arguments.handlerMeta.extends, arguments.action ) ) {
			return true;
		}

		var functions = arguments.handlerMeta.functions ?: [];

		for( var func in functions ) {
			if ( ( func.name ?: "" ) eq arguments.action ) {
				return true;
			}
		}

		return false;
	}
}
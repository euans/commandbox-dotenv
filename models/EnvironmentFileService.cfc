/**
 * Service for working with dotenv files
 */
component singleton="true" {

	property name="propertyFile" inject="provider:PropertyFile@propertyFile";
	property name='consoleLogger' inject='logbox:logger:console';
	property name='systemSettings' inject='systemSettings';
	property name="javaSystem" inject="java:java.lang.System";
	property name="moduleSettings" inject="commandbox:moduleSettings:commandbox-dotenv";
	property name='ConfigService' inject='ConfigService';
	
	this.NOT_EXISTS='______NOT_EXISTS______';
	variables.encryptionKey = "";

	public function getEnvStruct( envFilePath ) {
		if ( ! fileExists( envFilePath ) ) {
			return {};
		}

		var envFile = fileRead( envFilePath );

		if ( isJSON( envFile ) ) {
			return _decrypt(deserializeJSON( envFile ));
		}

		// Shim for old version of WireBox/CommandBox
		if( structKeyExists( propertyFile, '$get' ) ) {
			// WireBox >= 6
			var propFile = propertyFile.$get();
		} else {
			// WireBox <= 5.x
			var propFile = propertyFile.get();			
		}
		return _decrypt(propFile
			.load( envFilePath )
			.getAsStruct());
	}

	/**
	* @envStruct Struct of key/value pairs to load
	* @inParent Loads vars into the parent context so they persist outside of this current command
	*/
	public function loadEnvToCLI( required struct envStruct, boolean inParent=false, string encryptionProfile=moduleSettings.encryptionProfile ) {

		loadEncryptionKey(arguments.encryptionProfile);

		for (var key in envStruct) {

			// Shim for older versions of CommandBox
			if( !structKeyExists( systemSettings, 'setSystemSetting' ) ) {
				javaSystem.setProperty( key, envStruct[ key ] );
			} else {
				systemSettings.setSystemSetting( key, envStruct[ key ], inParent );
			}

			if( moduleSettings.printOnLoad && moduleSettings.verbose ) {
				consoleLogger.info( "commandbox-dotenv: #key#=#envStruct[ key ]#" );
			}

		}	

	}

	public array function diff( required struct source, required struct target ) {
		return arguments.source.reduce( ( acc, key ) => {
			// If the key isn't in the target file AND isn't defined in the current environment already
			if ( ! target.keyExists( arguments.key ) && systemSettings.getSystemSetting( arguments.key, this.NOT_EXISTS ) == this.NOT_EXISTS ) {
				arguments.acc.append( arguments.key );
			}
			return arguments.acc;
		}, [] );
	}

	public function generateEncryptionKey ( string key=generateSecretKey('aes') ) {
		return _stringToHex(arguments.key);
	}

	private function loadEncryptionKey ( string profile=moduleSettings.encryptionProfile ) {
		var configSettings = ConfigService.getConfigSettings();
		cfparam (name='configSettings.modules["commandbox-dotenv"].encryptionProfiles', default={});

		local.encryptionKey = configSettings.modules["commandbox-dotenv"].encryptionProfiles[arguments.profile]?:'';
		if ( !local.encryptionKey.len() ) {
			configSettings.modules["commandbox-dotenv"].encryptionProfiles[arguments.profile] = generateEncryptionKey();
			ConfigService.setConfigSettings( configSettings );
			local.encryptionKey = configSettings.modules["commandbox-dotenv"].encryptionProfiles[arguments.profile];
		}
		variables.encryptionKey = local.encryptionKey;
		consoleLogger.info( "commandbox-dotenv: #arguments.profile#" );
		return variables.encryptionKey;
	}

	private function _decrypt ( any data ) {
		if ( isSimpleValue(arguments.data) ) {
			return _decryptString(arguments.data);
		} else if ( isStruct(arguments.data) ) {
			return arguments.data.map( ( v,i,s ) => {
				return _decrypt(i);
			});
		} else if ( isArray(arguments.data) ) {
			return arguments.data.map( ( v,i ) => {
				return _decrypt(v);
			});
		}
		return arguments.data;
	}

	public function encryptString ( required string string ) {		
		return encrypt(arguments.string, _hexToString(variables.encryptionKey), 'aes', 'hex');
	}

	private function _decryptString ( required string string ) {
		if ( arguments.string.reFindNoCase('^encrypted:') ) {
			arguments.string = arguments.string.replaceAll('encrypted\:\s*([^"\n\r]*)', '$1');
			try {
				return decrypt(arguments.string, _hexToString(variables.encryptionKey), 'aes', 'hex');
			} catch ( any e ) {}
		}
		return arguments.string;
	}
    
    private function _hexToString( required string string ){
        local.binaryValue = binaryDecode( arguments.string, "hex" );
        local.stringValue = toString( local.binaryValue );
        return local.stringValue;
    }

    private function _stringToHex( required string string ) {
        local.binaryValue = toBinary(toBase64( arguments.string ));
        local.hexValue = binaryEncode( local.binaryValue, "hex" );
        return lcase( local.hexValue );
    }

}

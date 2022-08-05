/**
 * Encrypt string for placement in the .env.
 * .
 * {code:bash}
 * dotenv encrypt 'hello world'
 * {code}
 */
component accessors="true" {
    property name="envFileService" inject="EnvironmentFileService@commandbox-dotenv";

    /**
     * @string String to encrypt. 
     */
    function run( required string string ) {
		print
            .greenText('encrypted:')
            .text(envFileService.encryptString(arguments.string).lcase());
	}

}

nagios_win_printers_plugin
==========================

El plugin requiere de guardar un archivo CSV en el servidores de impresión con los datos previos de la impresora. 
Actualmente acepta dos parametros, donde guardar el CSV (por defecto C:\temp\check_win_printers.csv) y la cantidad de días offline para dar la alerta.
Sería sencillo extenderlo a más controles o distintos umbrales para los WARNING y CRITICAL.

INSTALACIÓN:
============

Por lo que probé no requiere actualizar powershell, con la versión por defecto de Windows 2008 R2 funciona.

nsclient
--------

El plugin debe que estar en todos los servidores de impresión, C:\scripts\check_win_printers.ps1 (*usar rol de ansible para nsclient*)

Contenido para *NSC.ini* de cada servidor de impresión (*usar rol de ansible para nsclient*):

Ejemplo:

    ; A list of scripts available to run from the CheckExternalScripts module. Syntax is: <command>=<script> <arguments>
    [/settings/external scripts/scripts]
	; --- omitted lines ---
    check_win_printers=powershell -ExecutionPolicy Bypass -File c:\scripts\check_win_printers.ps1 -File $ARG1$ -DaysOffline $ARG2$


Definición en Nagios:
---------------------

Comando: 

	define command{ 
			command_name                  check_nrpe_win_printers 
			command_line                  /usr/lib/nagios/plugins/check_nrpe -H $HOSTADDRESS$ -p 5666 -t 60 -c check_win_printers -a $ARG1$ $ARG2$ 
	} 
  


Servicio (*usar rol de ansible para nagios_config*):

Ej:

	define service { 
			hostgroup_name               PRINT_SERVERS
			service_description          Check Offiline Printers 
			check_command                check_nrpe_win_printers!C:\temp\check_win_printers.csv!5
			use                          generic-service 
	}


Notas
=====

La API de Windows que usa tiene algunas falencias, como que muchos de los status que devuelve depende directamente del driver, y no todos los proveedores usan los mismo códigos de error. 
Un ejemplo puntual, cuando una impresa tiene poco toner algunos drivers devuelven que la impresora tiene un problema, y Windows no la diferencia de ninguna manera de una impresora offiline.
Este caso en particular lo solucioné, pero podrían aparecer otros a futuro, que también se solucionan revisando un poco.

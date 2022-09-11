#include <sourcemod>

Database db;

bool Authorized[MAXPLAYERS+1] = {false,...};

public void OnPluginStart()
{
	Database.Connect(SQLCallbax, "register");

	AddCommandListener(JoinTeam, "jointeam");
	RegConsoleCmd("sm_login", Command, "Type sm_login \"password\" for login");							//Залогиниться
	RegConsoleCmd("sm_reg", Command, "Type sm_reg \"password\" for registration");						//Зарегистрироваться
	RegConsoleCmd("sm_pass", Command, "Type sm_pass \"old_pass:new_pass\" for change self password");		//Изменить данные
	
	RegConsoleCmd("sm_remove_accounts", Remove, "Type sm_remove_accounts \"all/steam_id\" for change self password", ADMFLAG_ROOT); //Удалить аккаунт/таблицу
}

public Action Remove(int client, int args)
{
	char buffer[256], sQuery[256];
	GetCmdArg(1, buffer, sizeof(buffer));
	if(StrEqual(buffer, "all")) SQL_FormatQuery(db, sQuery, sizeof(sQuery), "DROP TABLE `regs`");
	else if(StrEqual(buffer[9], ":")) SQL_FormatQuery(db, sQuery, sizeof(sQuery), "DELETE FROM `regs` WHERE `steam_id`='%s'", buffer);
	SQL_TQuery(db, SQLT, sQuery);
	return Plugin_Handled;
}

public void SQLCallbax(Database dbi, const char[] error, any data)
{
	if(!error[0] || dbi != INVALID_HANDLE) 
	{
		db = dbi; 
		CreateTables();
	}

	else 
	{
		SetFailState("[REG] Database ERROR: %s", error);
		return;
	}
}

public void CreateTables()
{
	char sQuery[256];
	SQL_FormatQuery(db, sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `regs` (\
																		`player_id` AUTO_INCREMENT, \
																		`steam_id` VARCHAR(64) NOT NULL PRIMARY KEY, \
																		`name` VARCHAR(64) NOT NULL , \
																		`password` VARCHAR(64) NOT NULL , \
																		`last_connect` INTEGER(11) NOT NULL, \
																		`registration_data` INTEGER(11) NOT NULL)");
	SQL_TQuery(db, SQLT, sQuery);
}

public void OnClientConnected(int client)
{
	Authorized[client] = false;
}

public void OnClientDisconnect(int client)
{
	Authorized[client] = false;
}

public Action Command(int client, int args)
{
	char cmd[2][256], sQuery[256], auth[22];
	GetCmdArg(0, cmd[0], 256);
	GetCmdArg(1, cmd[1], 256);
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	if(StrEqual(cmd[0], "sm_login"))
	{
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "SELECT `steam_id` FROM `regs` WHERE `password`='%s'", cmd[1]);
		DBResultSet result = SQL_Query(db, sQuery);
		if(result != INVALID_HANDLE && result.HasResults && result.RowCount == 1)
		{	
			char auth2[22];
			result.FetchRow();
			result.FetchString(0, auth2, sizeof(auth2));
			if(StrEqual(auth2, auth)) AuthOK(client);
		}
	}
	
	else if(StrEqual(cmd[0], "sm_reg"))
	{
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "INSERT INTO `regs` (`steam_id`,`name`,`password`,`last_connect`,`registration_data`) VALUES ('%s', '%N', '%s', '%i', '%i')", auth, client, cmd[1], GetTime(), GetTime());
		SQL_TQuery(db, SQLT, sQuery);
		char er[256];
		if(SQL_GetError(db, er, sizeof(er)))
		{
			SetFailState("[REG] Database ERROR: %s", er);
			return Plugin_Handled;
		}
		else PrintToChat(client, "Вы успешно зарегистрировались. Авторизуйтесь при помощи sm_reg \"password\"");
	}
	
	else if(StrEqual(cmd[0], "sm_pass"))
	{
		char buffer[512], pass[2][256];
		GetCmdArg(1, buffer, sizeof(buffer));
		ExplodeString(buffer, ":", pass, 2, 256);
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "UPDATE `regs` SET `password`='%s' WHERE `steam_id`='%s'", pass[1], auth);
		SQL_TQuery(db, SQLT, sQuery);
		char er[256];
		if(SQL_GetError(db, er, sizeof(er)))
		{
			SetFailState("[REG] Database ERROR: %s", er);
			return Plugin_Handled;
		}
		else PrintToChat(client, "Пароль успешно обновлен");
	}
	return Plugin_Handled;
}

public void AuthOK(int client)
{
	Authorized[client] = true;
	PrintToChat(client, "Вы успешно авторизировались");
}

public void SQLT(Handle owner, Handle hndl, const char[] error, any data)
{
	if(error[0] || hndl == INVALID_HANDLE)
	{
		SetFailState("[REG] Database ERROR: %s", error);
		return;
	}
}

public Action JoinTeam(int client, const char[] command, int args)
{
	if(Authorized[client] == false) 
	{
		PrintToChat(client, "Авторизуйтесь перед тем как зайти за команду.\nВведите sm_login pass для авторизации или sm_reg pass для регистрации");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

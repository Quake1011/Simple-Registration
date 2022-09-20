#include <sourcemod>

Database db;

bool Authorized[MAXPLAYERS+1] = {false,...};

public Plugin myinfo = 
{
    name = "Simple Reg",
    author = "Quake1011",
    description = "Test reg plugin",
    version = "1.0",
    url = "https://github.com/Quake1011/"
}

public void OnPluginStart()
{
	Database.Connect(SQLCallbax, "register");

	AddCommandListener(JoinTeam, "jointeam");
	RegConsoleCmd("sm_login", Command, "Type sm_login \"password\" for login");									//Залогиниться
	RegConsoleCmd("sm_reg", Command, "Type sm_reg \"password\" for registration");								//Зарегистрироваться
	RegConsoleCmd("sm_pass", Command, "Type sm_pass \"old_pass:new_pass\" for change self password");			//Изменить данные
	RegConsoleCmd("sm_remove_accounts", Remove, "Type sm_remove_accounts \"all/steam_id\" for change self password", ADMFLAG_ROOT); //Удалить аккаунт/таблицу
}

public Action Remove(int client, int args)
{
	char buffer[256], sQuery[256];
	GetCmdArg(1, buffer, sizeof(buffer));
	if(StrEqual(buffer, "all")) SQL_FormatQuery(db, sQuery, sizeof(sQuery), "DROP TABLE `regs`");
	else if(StrEqual(buffer[9], ":")) SQL_FormatQuery(db, sQuery, sizeof(sQuery), "DELETE FROM `regs` WHERE `steam_id`='%s'", buffer);
	SQL_FastQuery(db, sQuery);
	return Plugin_Handled;
}

public void SQLCallbax(Database dbi, const char[] error, any data)
{
	if(!error[0] && dbi != INVALID_HANDLE) 
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

void CreateTables()
{
	char sQuery[256];
	SQL_LockDatabase(db);
	SQL_FormatQuery(db, sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `regs` (\
												`player_id` AUTO_INCREMENT, \
												`steam_id` VARCHAR(64) NOT NULL PRIMARY KEY, \
												`name` VARCHAR(64) NOT NULL , \
												`password` VARCHAR(64) NOT NULL , \
												`last_auth` INTEGER(11) NOT NULL, \
												`registration_date` INTEGER(11) NOT NULL)");
	SQL_FastQuery(db, sQuery);
	SQL_UnlockDatabase(db);
}

public void OnClientConnected(int client)
{
	Authorized[client] = false;
}

public void OnClientDisconnect(int client)
{
	Authorized[client] = false;
}

public void SQL_LoginCB(Database hDb, DBResultSet results, const char[] error, any data)
{
	
	if(error[0] || !results)
	{
		SetFailState("Error: %s", error);
		return;
	}
	
	if(results.HasResults && results.FetchRow() && results.RowCount == 1)
	{
		DataPack hPack = view_as<DataPack>(data);
		char auth2[22], auth[22];
		hPack.ReadString(auth, sizeof(auth));
		int client = hPack.ReadCell();
		results.FetchRow();
		results.FetchString(0, auth2, sizeof(auth2));
		if(StrEqual(auth2, auth)) AuthOK(client, auth2);
	}
}

public void SQL_RegCB(Database hDb, DBResultSet results, const char[] error, int client)
{
	if(error[0] || !results)
	{
		SetFailState("Error: %s", error);
		return;
	}
	PrintToChat(client, "Вы успешно зарегистрировались. Авторизуйтесь при помощи sm_reg \"password\"");
}

public void SQL_PassCB(Database hDb, DBResultSet results, const char[] error, int client)
{
	if(error[0] || !results)
	{
		SetFailState("[REG] Database ERROR: %s", error);
		return;	
	}
	PrintToChat(client, "Пароль успешно обновлен");
}

public Action Command(int client, int args)
{
	char cmd[2][256], sQuery[256], auth[22];
	GetCmdArg(0, cmd[0], 256);
	GetCmdArg(1, cmd[1], 256);
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	if(StrEqual(cmd[0], "sm_login"))
	{
		DataPack dp = CreateDataPack();
		dp.WriteString(auth);
		dp.WriteCell(client);
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "SELECT `steam_id` FROM `regs` WHERE `password`='%s'", cmd[1]);
		db.Query(SQL_LoginCB, sQuery, dp, DBPrio_High);
	}
	
	else if(StrEqual(cmd[0], "sm_reg"))
	{
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "INSERT INTO `regs` (\
													`steam_id`,\
													`name`,\
													`password`,\
													`last_auth`,\
													`registration_data`) \
													VALUES (\
													'%s', \
													'%N', \
													'%s', \
													'%i', \
													'%i')", auth, client, cmd[1], GetTime(), GetTime());
		db.Query(SQL_RegCB, sQuery, client, DBPrio_High);
	}
	
	else if(StrEqual(cmd[0], "sm_pass"))
	{
		char buffer[512], pass[2][256];
		GetCmdArg(1, buffer, sizeof(buffer));
		ExplodeString(buffer, ":", pass, 2, 256);
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "UPDATE `regs` SET `password`='%s' WHERE `steam_id`='%s'", pass[1], auth);
		db.Query(SQL_PassCB, sQuery, client, DBPrio_High);
	}
	return Plugin_Handled;
}

void AuthOK(int client, char[] auth)
{
	char sQuery[256];
	Authorized[client] = true;
	PrintToChat(client, "Вы успешно авторизировались");
	SQL_FormatQuery(db, sQuery, sizeof(sQuery), "UPDATE `regs` SET `last_auth`='%i' WHERE `steam_id`='%s'", GetTime(), auth);
	SQL_FastQuery(db, sQuery);
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

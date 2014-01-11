/*
	@file: /internal/CAccounts.p
	@author: 
		l0nger <l0nger.programmer@gmail.com>
		
	@licence: GPLv2
	
	(c) 2013-2014, <l0nger.programmer@gmail.com>
*/

// TODO:
// 1) Wykonac tabele z uzytkownikami
// 2) Oprogramowac te funkcje

#define MAX_LOGIN_ATTEMPTS (4)

stock theplayer::isRegistered(playerid) {
	new bool:v=false;
	CMySQL_Query("SELECT 1 FROM accounts WHERE nickname='%s' LIMIT 1;", -1, PlayerData[playerid][epd_nickname]);
	mysql_store_result();
	if(mysql_num_rows()) v=true;
	mysql_free_result();
	return v;
}

stock theplayer::getAccountID(playerid) {
	if(PlayerData[playerid][epd_accountID]>0) return PlayerData[playerid][epd_accountID];
	CMySQL_Query("SELECT 1 FROM accounts WHERE nickname='%s' LIMIT 1;", -1, PlayerData[playerid][epd_nickname]);
	mysql_store_result();
	new tmpResult[12];
	if(mysql_num_rows()) {
		mysql_fetch_row(tmpResult);
	}
	mysql_free_result();
	return strval(tmpResult);
	
}

stock theplayer::isAccountExists(playerid, szAccount[]) {
	if(isnull(szAccount)) return false;
	new bool:v=false;
	CMySQL_Query("SELECT 1 FROM accounts WHERE nickname='%s' LIMIT 1;", -1, szAccount);
	mysql_store_result();
	if(mysql_num_rows()) v=true;
	mysql_free_result();
	return v;
}

stock theplayer::onEventLogin(playerid, input[]) {
	if(isnull(input)) return false;
	
	new bool:success=false, esc_input[32];
	mysql_real_escape_string(input, esc_input);
	CMySQL_Query("SELECT (password=SHA1(MD5('%s'))) AS validpwd FROM accounts WHERE nickname='%s';", -1, esc_input, PlayerData[playerid][epd_nickname]);
	mysql_store_result();
	success=!!mysql_fetch_int();
	mysql_free_result();
	
	if(success) {
		theplayer::loadAccountData(playerid);
		PlayerData[playerid][epd_accountID]=theplayer::getAccountID(playerid);
		theplayer::setAccountDataString(playerid, "NOW()", false, "ts_last");
		theplayer::setAccountDataString(playerid, PlayerData[playerid][epd_addressIP], true, "ip_last");
		theplayer::setAccountDataInt(playerid, 1, "isonline");
		theplayer::sendMessage(playerid, COLOR_INFO1, "Zalogowano pomy�lnie. Ostatnia wizyta na serwerze: %s", theplayer::getAccountDataString(playerid, "ts_last"));
		
		bit_unset(PlayerData[playerid][epd_properties], PLAYER_INLOGINDIALOG);
		bit_set(PlayerData[playerid][epd_properties], PLAYER_ISLOGGED);
		
		SetPlayerHealth(playerid, PlayerData[playerid][epd_lastHealth]);
		if(PlayerData[playerid][epd_lastArmour]>0) SetPlayerArmour(playerid, PlayerData[playerid][epd_lastArmour]);
		
		// TODO: Wczytywanie broni/amunicji w tym skilla z tabeli broni/amunicji ;p
		if(PlayerData[playerid][epd_spawnType]==0) {
			SetSpawnInfo(playerid, NO_TEAM, PlayerData[playerid][epd_lastSkin], PlayerData[playerid][epd_lastPos][0], PlayerData[playerid][epd_lastPos][1], PlayerData[playerid][epd_lastPos][2], PlayerData[playerid][epd_lastPos][3], 0, 0, 0, 0, 0, 0);
			SpawnPlayer(playerid);
			
		} else {
			// TODO: Wyszukanie domu i zespawnowanie gracza w domu
		}
		
	} else {
		if(++PlayerData[playerid][epd_loginAttempts]>=MAX_LOGIN_ATTEMPTS) {
			theplayer::hideDialog(playerid);
			theplayer::sendMessage(playerid, COLOR_ERROR, "Wykorzysta�e� maksymaln� ilo�� pr�b zalogowa� na to konto.");
			// TODO: Informowanie administracji o tym przypadku
			theadmins::sendMessage(COLOR_ERROR, RANK_ADMIN, "Pr�ba zalogowania na konto <b>%s<b> z adresu IP: <b>%s</b> - wyrzucony.", PlayerData[playerid][epd_nickname], PlayerData[playerid][epd_addressIP]);
			theplayer::kick(playerid);
			return false;
		}
		theplayer::sendMessage(playerid, COLOR_ERROR, "Wprowadzone has�o jest nieprawid�owe. Spr�buj ponownie.");
		theplayer::showLoginDialog(playerid);
	}
	return true;
}

stock theplayer::onEventRegister(playerid, input[]) {
	if(isnull(input)) return false;
	
	// TODO:
	// Dokonczyc rejestracje konta
	return true;
}

stock theplayer::hideDialog(playerid) {
	ShowPlayerDialog(playerid, DIALOG_BLANK, 0, "", "", "", "");
}

stock theplayer::showLoginDialog(playerid) {
	ShowPlayerDialog(playerid, 
		DIALOG_LOGIN, 
		DIALOG_STYLE_PASSWORD, 
		"Panel logowania", 
		"Witaj ponownie!\nKonto o tym nicku zosta�o ju� zarejestrowane.\n\
		Je�eli nie jeste� w�a�cicielem tego konta, wyjd� z serwera i zmie� nick.\n\
		Pamietaj, �e ka�da pr�ba logowania jest rejestrowana. W wi�kszo�ci przypadk�w mo�e to wi�za� si� z poniesiem odpowiednich konsekwencji.\n\
		Poni�ej wpisz swoje has�o podane przy rejestracji. Je�eli nie pami�tasz has�a - zg�o� ten przypadek do administracji lub sprawd� swojego e-maila.", 
		"Zaloguj", "Wyjdz");
}

stock theplayer::showRegisterDialog(playerid) {
	ShowPlayerDialog(playerid, 
		DIALOG_LOGIN, 
		DIALOG_STYLE_PASSWORD, 
		"Panel rejestracji konta", 
		"Witamy w panelu rejestracji konta. Decydujac si� na rejestracje otrzymasz pe�ny dost�p do wszystkich funkcji serwera.\n\
		Dodatkowo, gdy Twoje konto zostanie zarejestrowane - dostaniesz 500 RP nagrody - nie czekaj!\n\
		Poni�ej wpisz swoje has�o, za pomoc� kt�rego b�dziesz m�g� si� logowa�.\n\
		Pami�taj, �e Twoje has�o MUSI mie� co najmniej 6 do 16 znak�w. Has�o mo�e sk�ada� si� ze znak�w specjalnych.\n\
		W razie, gdyby� zapomnia� has�a - serwer automatycznie powiadomi Ci� o pr�bie zalogowania na Twoje konto i w tej b�dzie znajdowa� si� link, do mo�liwego zresetowania has�a.",
		"Rejestruj", "Anuluj");
	
}

stock theplayer::loadAccountData(playerid) {
	new tmpBuf[128], tmpPos[32], haveVIP;
	CMySQL_Query("SELECT skin, respect, level, hp, armour, pos, bank_money, wallet_money, spawnType, admin, IFNULL(DATEDIFF(vip, NOW()), '-1') FROM accounts WHERE nickname='%s' LIMIT 1;", -1, PlayerData[playerid][epd_nickname]);
	mysql_store_result();
	mysql_fetch_row(tmpBuf, "|");
	mysql_free_result();
	sscanf(tmpBuf, "p<|>dddffs[32]ddddd", 
		PlayerData[playerid][epd_lastSkin],
		PlayerData[playerid][epd_levelRP],
		PlayerData[playerid][epd_respect],
		PlayerData[playerid][epd_lastHealth],
		PlayerData[playerid][epd_lastArmour],
		tmpPos,
		PlayerData[playerid][epd_bankMoney],
		PlayerData[playerid][epd_walletMoney],
		PlayerData[playerid][epd_spawnType],
		PlayerData[playerid][epd_admin],
		haveVIP
	);
	sscanf(tmpPos, "p<;>ffff", PlayerData[playerid][epd_lastPos][0], PlayerData[playerid][epd_lastPos][1], PlayerData[playerid][epd_lastPos][2], PlayerData[playerid][epd_lastPos][3]);
	if(haveVIP>0) PlayerData[playerid][epd_haveVip]=true;
}

stock theplayer::setAccountDataInt(playerid, data, column[]) {
	CMySQL_Query("UPDATE accounts SET %s='%d' WHERE id='%d';", -1, column, data, PlayerData[playerid][epd_accountID]);
}

stock theplayer::setAccountDataString(playerid, data[], bool:useApostrofy=false, column[]) {
	if(useApostrofy) CMySQL_Query("UPDATE accounts SET %s='%s' WHERE id='%d';", -1, column, data, PlayerData[playerid][epd_accountID]);
	else CMySQL_Query("UPDATE accounts SET %s=%s WHERE id='%d';", -1, column, data, PlayerData[playerid][epd_accountID]);
}

stock theplayer::getAccountDataInt(playerid, column[]) {
	new tmpResult[12];
	CMySQL_Query("SELECT %s FROM accounts WHERE id='%d' LIMIT 1;", -1, column, PlayerData[playerid][epd_accountID]);
	mysql_store_result();
	if(mysql_num_rows()) mysql_fetch_row(tmpResult);
	mysql_free_result();
	return strval(tmpResult);
}

stock theplayer::getAccountDataString(playerid, column[]) {
	new tmpResult[32];
	CMySQL_Query("SELECT %s FROM accounts WHERE id='%d' LIMIT 1;", -1, column, PlayerData[playerid][epd_accountID]);
	mysql_store_result();
	if(mysql_num_rows()) mysql_fetch_row(tmpResult);
	mysql_free_result();
	return tmpResult;
}

stock theplayer:getAccountDataFloat(playerid, column[]) {
	new tmpResult[22];
	CMySQL_Query("SELECT %s FROM accounts WHERE id='%d' LIMIT 1;", -1, column, PlayerData[playerid][epd_accountID]);
	mysql_store_result();
	if(mysql_num_rows()) mysql_fetch_row(tmpResult);
	mysql_free_result();
	return floatstr(tmpResult);
}

#undef MAX_LOGIN_ATTEMPTS
/*
	@file: /internal/CVehicles.p
	@author: 
		l0nger <l0nger.programmer@gmail.com>
		Zielony745 <SzymonGeek@gmail.com>
		
	@licence: GPLv2
	
	(c) 2013-2014, <l0nger.programmer@gmail.com>
*/

#define thevehicle:: thevehicle_

#define thevehicle_unpackXYZ(%0) VehicleData[%0-1][evd_pos][0],VehicleData[%0-1][evd_pos][1],VehicleData[%0-1][evd_pos][2]
#define thevehicle_unpackXYZR(%0) VehicleData[(%0)-1][evd_pos][0],VehicleData[(%0)-1][evd_pos][1],VehicleData[(%0)-1][evd_pos][2],VehicleData[(%0)-1][evd_pos][3]
#define thevehicle_unpackpos(%0,%1,%2,%3) %0[%1],%0[%2],%0[%3]
#define thevehicle_unpackColor(%0) %0[0],%0[1]

#define thevehicle_getDoorEnterType(%0) VehicleData[(%0)-1][evd_doorEnterType]
#define thevehicle_getOwner(%0) VehicleData[(%0)-1][evd_ownerID]
#define thevehicle_getProperties(%0) VehicleData[(%0)-1][evd_properties]
#define thevehicle_getUniqueID(%0) VehicleData[(%0)-1][evd_uid]

enum
{
	VEHICLE_ENTER_NOBODY=0,
	VEHICLE_ENTER_FRIENDS,
	VEHICLE_ENTER_GANGMEMBERS,
	VEHICLE_ENTER_ALL
};

stock CVehicles_Init() 
{
	CVehicles_loadAll();
}

stock CVehicles_Exit() 
{
	new count;
	for(new vehicleid=0; vehicleid<MAX_VEHICLES; vehicleid++) 
	{
		//thevehicle::save(vehicleid);
		count++;
	}
	printf("[CVehicles]: Saved %d vehicles", count);
}

stock CVehicles_loadAll() 
{
	new buf[128], tmpTuning[128], addData[12], tmpColor[2];
	CMySQL_Query("SELECT id, modelid, fX, fY, fZ, fAng, doors, dmgPanels, dmgDoors, dmgLights, dmgTires, color1, color2, tuning, hp FROM vehicles WHERE owner=0;", -1);
	mysql_store_result();
	new i, vid;
	while(mysql_fetch_row(buf, "|")) 
	{
		sscanf(buf, "p<|>ddffffddddddds[128]f", 
			addData[0], addData[1], 
			Float:addData[2], Float:addData[3], 
			Float:addData[4], Float:addData[5], 
			addData[6],
			addData[7], addData[8], 
			addData[9], addData[10],
			tmpColor[0], tmpColor[1],
			tmpTuning, addData[11]
		);	
		
		vid=thevehicle::create(addData[1], addData[0], _, thevehicle::unpackpos(Float:addData,2,3,4), Float:addData[5], tmpColor);
		sscanf(tmpTuning, "p<;>a<d>[12]", VehicleData[vid-1][evd_tuning]);
		for(new j; j<12; j++) {
			AddVehicleComponent(vid, VehicleData[vid-1][evd_tuning][j]);
		}
		UpdateVehicleDamageStatus(vid, addData[7], addData[8], addData[9], addData[10]);
		i++;
	}
	mysql_free_result();
	printf("[CVehicles]: Loaded %d vehicles", i);
}

//Kod zostanie dokończony w najbliższym czasie!
stock thevehicle::save(vehid)
{
	new Float:hp, dmgStatus[4];
	
	GetVehicleHealth(vehid, hp);
	GetVehicleDamageStatus(vehid, dmgStatus[0], dmgStatus[1], dmgStatus[2], dmgStatus[3]);
	
	if(hp<300) hp=300.0;
	CMySQL_Query(
		"UPDATE vehicles SET fX='%f', fY='%f', fZ='%f', fAng='%f', color1=%d, color2=%d WHERE id=%d", 
		-1, // resultid 
		thevehicle::unpackXYZR(vehid), 
		thevehicle::unpackColor(VehicleData[vehid-1][evd_color]), 
		thevehicle::getUniqueID(vehid)
	);
}
//

stock thevehicle::create(modelid, vuid=-1, owner=INVALID_PLAYER_ID, Float:x=0.0, Float:y=0.0, Float:z=1.0, Float:rot=90.0, color[2]) 
{
	// Jezeli vuid ma wartosc -1 to pojazd jest tworzony jako 'anonim' i nie zostaje zapisywany do bazy danych
	if(modelid<400) return false;
	
	new carid=CreateVehicle(modelid, x, y, z, rot, color[0], color[1], DURATION(3 hours));
	VehicleData[carid-1][evd_carid]=carid;
	VehicleData[carid-1][evd_modelid]=modelid;
	VehicleData[carid-1][evd_pos][0]=x;
	VehicleData[carid-1][evd_pos][1]=y;
	VehicleData[carid-1][evd_pos][2]=z;
	VehicleData[carid-1][evd_pos][3]=rot;
	
	if(vuid!=-1) VehicleData[carid-1][evd_uid]=vuid;
	
	VehicleData[carid-1][evd_color][0]=color[0];
	VehicleData[carid-1][evd_color][1]=color[1];
	
	if(owner==INVALID_PLAYER_ID) 
	{
		bit_set(VehicleData[carid-1][evd_properties], VEHICLE_DOOR_OPEN);
		VehicleData[carid-1][evd_ownerID]=INVALID_PLAYER_ID;
		VehicleData[carid-1][evd_doorEnterType]=VEHICLE_ENTER_ALL;
	} else {
		bit_set(VehicleData[carid-1][evd_properties], VEHICLE_ISOWNED);
		bit_set(VehicleData[carid-1][evd_properties], VEHICLE_DOOR_CLOSED); // zamykamy pojazd przed innymi osobnikami
		VehicleData[carid-1][evd_doorEnterType]=VEHICLE_ENTER_NOBODY;
		VehicleData[carid-1][evd_ownerID]=owner;
	}
	return carid;
}

CMD:addpojazd(playerid, params[]) 
{
	if(!theplayer::isAdmin(playerid, RANK_DEV)) return theplayer::sendMessage(playerid, COLOR_ERROR, "[E] Brak uprawnien do uzywania tej komendy!");
	
	new Float:PP[4], tmpColor[2];
	GetPlayerPos(playerid, PP[0], PP[1], PP[2]);
	GetPlayerFacingAngle(playerid, PP[3]);
	tmpColor[0]=random(250);
	tmpColor[1]=random(250)+1;
	thevehicle::create(strval(params), _, _, PP[0], PP[1], PP[2], PP[3], tmpColor);
	CMySQL_Query("INSERT INTO vehicles (modelid, fX, fY, fZ, fAng, color1, color2) VALUES (%d, '%f', '%f', '%f', '%f', %d, %d);", -1, strval(params), PP[0], PP[1], PP[2], PP[3], tmpColor[0], tmpColor[1]);
	return 1;
}

#undef thevehicle_unpackXYZ
#undef thevehicle_unpackXYZR
#undef thevehicle_unpackpos
wmic diskdrive get InterfaceType,MediaType,name,status
wmic /namespace:\\root\wmi path MSStorageDriver_FailurePredictStatus
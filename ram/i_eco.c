#include <windows.h>
void __stdcall start(void){ PROCESS_POWER_THROTTLING_STATE s={PROCESS_POWER_THROTTLING_CURRENT_VERSION,PROCESS_POWER_THROTTLING_EXECUTION_SPEED,PROCESS_POWER_THROTTLING_EXECUTION_SPEED};
 SetProcessInformation(GetCurrentProcess(),ProcessPowerThrottling,&s,sizeof s); SetPriorityClass(GetCurrentProcess(),IDLE_PRIORITY_CLASS);
 for(;;){ Sleep(1); } }

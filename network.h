#ifndef _NETWORK_H_
#define _NETWORK_H_

#include <string>

#include <stdio.h>
#include <string.h>
#include <iostream>
#include <netinet/in.h>
#include <net/if.h>



class NetworkInfoHelper
{

	public:
		class AdapteInfo
		{
			public:
				AdapteInfo(){clear();}

				AdapteInfo(const AdapteInfo &info){ copy(info);}

				AdapteInfo& operator=(const AdapteInfo &info){return copy(info);}

				AdapteInfo& copy(const AdapteInfo &info)
				{
					this->adapter_name = info.adapter_name;
					this->adapter_dec = info.adapter_dec;
					this->local_ipv4 = info.local_ipv4;
					this->local_ipv6 = info.local_ipv6;
					this->gateway_ipv4 = info.gateway_ipv4;
					this->mask_ipv4 = info.mask_ipv4;
					this->dhcp_ipv4 = info.dhcp_ipv4;
					this->index = info.index;
					memcpy(this->local_mac, info.local_mac, 6);
					memcpy(this->gateway_mac, info.gateway_mac, 6);

					return *this;
				}	

		

				void clear()
				{
					this->adapter_name = "";
					this->adapter_dec = "";
					this->local_ipv4.s_addr = 0;
					this->gateway_ipv4.s_addr = 0;
					this->mask_ipv4.s_addr = 0;
					this->dhcp_ipv4.s_addr = 0;
					this->index = -1;
					memset(&this->local_ipv6, 0, sizeof(this->local_ipv6));
					memset(this->local_mac, 0, 6);
					memset(this->gateway_mac, 0, 6);
				}

			public:
				std::string adapter_name;
				std::string adapter_dec;
				struct in_addr local_ipv4;
				struct in6_addr local_ipv6;
				unsigned char local_mac[6];
				struct in_addr gateway_ipv4;
				unsigned char gateway_mac[6];
				struct in_addr mask_ipv4;
				struct in_addr dhcp_ipv4;
				unsigned int index;

			public:
				AdapteInfo *next;
		};


		class WifiInfo
		{
			public:
				WifiInfo(){clear();}

				WifiInfo(const WifiInfo &info){ copy(info);}

				WifiInfo& operator=(const WifiInfo &info){return copy(info);}

				WifiInfo& copy(const WifiInfo &info)
				{
					this->adapter_name = info.adapter_name;
					this->adapter_dec = info.adapter_dec;
					this->bssid = info.bssid;
					this->pwsd = info.pwsd;
					this->ssid = info.ssid;

					return *this;
				}

				void clear()
				{
					this->adapter_name = "";
					this->adapter_dec = "";
					this->bssid = "";
					this->pwsd = "";
					this->ssid = "";
				}

			public:
				std::string adapter_name;
				std::string adapter_dec;
				std::string bssid;
				std::string pwsd;
				std::string ssid;

			public:
				WifiInfo *next;
	
		};


		class interface
		{
			public:
				interface()
				{
					clear();
				}

				interface(const interface &i)
				{
					copy(i);
				}

				interface& operator=(const interface &i){return copy(i);}

				interface& copy(const interface &i)
				{
					this->adaptor = i.adaptor;
					this->wifi = i.wifi;
					this->is_wifi = i.is_wifi;

					return *this;
				}	

				void clear()
				{
					this->adaptor.clear();
					this->wifi.clear();
					this->is_wifi = -1;
				}

			public:
				AdapteInfo adaptor;
				WifiInfo   wifi;
				int is_wifi;

			public:
				interface *next;

		};


		class RouteInfo
		{
			public:
				RouteInfo():dst_ipv4(0), dst_mask(0), gateway(0),src_ipv4(0), metric(0), index(-1){};

				void print()
				{
					printf("****Route info:\r\n");
					printf("dst		|mask		|gateway	|src		|metric	|index\r\n");
					printf("0x%08x\t0x%08x\t0x%08x\t0x%08x\t%d\t%d\r\n", this->dst_ipv4, this->dst_mask,this->gateway,this->src_ipv4, this->metric, this->index);
					printf("--------------------------------------\r\n");
				}

				unsigned int dst_ipv4;
				unsigned int dst_mask;
				unsigned int src_ipv4;
				unsigned int gateway;
				unsigned int metric;
				unsigned int index;

			public:
				RouteInfo *next;
		};

		
	public:
		template<class Type>
			void free_list(Type pinfo)
			{
				Type next;
				Type entry = pinfo;

				while(entry)
				{
					next = entry->next;

					delete entry;
					
					entry = next;
				}
			};

		template<class Type>
		static	void list_link(Type pinfo, Type *pphead)
			{
				if(!*pphead)
				{
					*pphead = pinfo;
					pinfo->next = NULL;
				}
				else
				{
					pinfo->next = *pphead;
					*pphead = pinfo;
				}
			};

		static NetworkInfoHelper& GetInstance();

		static AdapteInfo* GetAllAdapterInfo();

		static RouteInfo* GetAllRouteInfo();

		static WifiInfo* GetAllWifiInfo();

		static interface* GetAllInterface();

	private:
		NetworkInfoHelper();

		int GetDefaultGateway(unsigned int &ip, unsigned int &eth_index);

		void getAdapterInfo();

		void getMac(unsigned int dst_ip, AdapterInfo *, unsigned char mac[],unsigned int timeout);
		
		static int readNlSock(int sock, char *msg, int seq, int pid);
		
		static int parseOneRoute(struct nlmsghdr *nlHdr, RouteInfo *rtinfo);

	private:
		interface m_cur_if;

};






#endif

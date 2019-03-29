#ifndef _NETWORK_H_
#define _NETWORK_H_


class NetworkInfoHelper
{
	
	public:
		class AdapteInfo
		{
			public:
				AdapteInfo(){clear();};

				AdapteInfo(const AdapteInfo &info){return copy(info)};

				AdapteInfo& operator=(const AdapteInfo &info){return copy(info)};

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





};






#endif

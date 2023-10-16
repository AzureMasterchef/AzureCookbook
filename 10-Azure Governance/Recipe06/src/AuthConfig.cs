using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace src
{
    internal class AuthConfig
    {
        public string ClientId { get; set; }
        public string ClientSecret { get; set; }
        public string TenantId { get; set; }

        public void Load(IConfiguration configuration)
        {
            this.ClientId = configuration["ClientId"];
            this.ClientSecret = configuration["ClientSecret"];
            this.TenantId = configuration["TenantId"];
        }
    }
}

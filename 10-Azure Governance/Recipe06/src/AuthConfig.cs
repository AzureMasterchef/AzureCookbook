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
        public string ManagedIdentityId { get; set; }

        public void Load(IConfiguration configuration)
        {
            this.ManagedIdentityId = configuration["ManagedIdentityId"];
        }
    }
}

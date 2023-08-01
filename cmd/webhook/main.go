package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"sync"

	"github.com/huaweicloud/huaweicloud-sdk-go-v3/core/auth/basic"
	dns "github.com/huaweicloud/huaweicloud-sdk-go-v3/services/dns/v2"
	dnsmodel "github.com/huaweicloud/huaweicloud-sdk-go-v3/services/dns/v2/model"
	dnsregion "github.com/huaweicloud/huaweicloud-sdk-go-v3/services/dns/v2/region"
	"github.com/octohelm/x/ptr"

	extapi "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	"k8s.io/client-go/rest"

	"github.com/cert-manager/cert-manager/pkg/acme/webhook/apis/acme/v1alpha1"
	"github.com/cert-manager/cert-manager/pkg/acme/webhook/cmd"
	"github.com/cert-manager/cert-manager/pkg/issuer/acme/dns/util"
)

var GroupName = os.Getenv("GROUP_NAME")

func main() {
	if GroupName == "" {
		panic("GROUP_NAME must be specified")
	}

	cmd.RunWebhookServer(GroupName, &customDNSProviderSolver{})
}

type customDNSProviderSolver struct {
	dnsClients sync.Map
}

type customDNSProviderConfig struct {
	Region    string `json:"region"`
	ZoneId    string `json:"zoneId"`
	AppKey    string `json:"appKey"`
	AppSecret string `json:"appSecret"`
}

func (c *customDNSProviderSolver) Name() string {
	return "huawei-dns"
}

func (c *customDNSProviderSolver) Present(ch *v1alpha1.ChallengeRequest) error {
	cfg, err := loadConfig(ch.Config)
	if err != nil {
		return err
	}

	fmt.Printf("Creating fqdn:[%s] zone:[%s]\n", ch.ResolvedFQDN, ch.ResolvedZone)

	domainName := c.extractDomainName(ch.ResolvedZone)

	dc, err := c.dnsClient(domainName, cfg)
	if err != nil {
		return err
	}

	_, err = dc.CreateRecordSet(&dnsmodel.CreateRecordSetRequest{
		ZoneId: cfg.ZoneId,
		Body: &dnsmodel.CreateRecordSetRequestBody{
			Type: "TXT",
			Name: ch.ResolvedFQDN,
			Records: []string{
				strconv.Quote(ch.Key),
			},
		},
	})

	if err != nil {
		fmt.Printf("%s\n, %#v", err, ch)
	}

	return nil
}

func (c *customDNSProviderSolver) CleanUp(ch *v1alpha1.ChallengeRequest) error {
	cfg, err := loadConfig(ch.Config)
	if err != nil {
		return err
	}

	dc, err := c.dnsClient(ch.ResolvedZone, cfg)
	if err != nil {
		return err
	}

	resp, err := dc.ListRecordSetsByZone(&dnsmodel.ListRecordSetsByZoneRequest{
		ZoneId: cfg.ZoneId,
		Name:   ptr.String(ch.ResolvedFQDN),
		Type:   ptr.String("TXT"),
	})
	if err != nil {
		return err
	}

	if sets := *resp.Recordsets; len(sets) != 0 {
		_, err = dc.DeleteRecordSet(&dnsmodel.DeleteRecordSetRequest{
			ZoneId:      cfg.ZoneId,
			RecordsetId: *sets[0].Id,
		})
		return err
	}

	return nil
}

func (c *customDNSProviderSolver) dnsClient(domain string, cfg customDNSProviderConfig) (*dns.DnsClient, error) {
	v, ok := c.dnsClients.Load(domain)
	if ok {
		return v.(*dns.DnsClient), nil
	}

	auth := basic.NewCredentialsBuilder().
		WithAk(cfg.AppKey).
		WithSk(cfg.AppSecret).
		Build()

	hc := dns.DnsClientBuilder().
		WithCredential(auth).
		WithRegion(dnsregion.ValueOf(cfg.Region)).
		Build()

	client := dns.NewDnsClient(hc)

	c.dnsClients.Store(domain, client)
	return client, nil
}

func (c *customDNSProviderSolver) extractDomainName(zone string) string {
	authZone, err := util.FindZoneByFqdn(zone, util.RecursiveNameservers)
	if err != nil {
		return zone
	}
	return util.UnFqdn(authZone)
}

func (c *customDNSProviderSolver) Initialize(kubeClientConfig *rest.Config, stopCh <-chan struct{}) error {
	return nil
}

func loadConfig(cfgJSON *extapi.JSON) (customDNSProviderConfig, error) {
	cfg := customDNSProviderConfig{}
	// handle the 'base case' where no configuration has been provided
	if cfgJSON == nil {
		return cfg, nil
	}
	if err := json.Unmarshal(cfgJSON.Raw, &cfg); err != nil {
		return cfg, fmt.Errorf("error decoding solver config: %v", err)
	}

	return cfg, nil
}

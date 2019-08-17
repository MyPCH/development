local helpers = import 'helpers.jsonnet';

local ManagedPolicy(config, group) = helpers.iamManagedPolicy(config, group) {
  values+:: {
    Properties+: {
      PolicyDocument+: {
        Statement: [
          {
            Effect: 'Allow',
            Action: 'route53:ChangeResourceRecordSets',
            Resource: 'arn:aws:route53:::hostedzone/*',
          },
          {
            Effect: 'Allow',
            Action: [
              'route53:GetChange',
              'route53:ListHostedZones',
              'route53:ListResourceRecordSets',
              'route53:ListHostedZonesByName',
            ],
            Resource: '*',
          },
        ],
      },
    },
  },
};

local ClusterIssuer(config, group, server, name) = {
  apiVersion: 'certmanager.k8s.io/v1alpha1',
  kind: 'ClusterIssuer',
  metadata: {
    name: name,
    namespace: group.namespace.name,
  },
  spec: {
    acme: {
      server: server,
      email: config.company.email,
      privateKeySecretRef: {
        name: name,
      },
      solvers: [
        {
          dns01: {
            route53: {
              region: config.cluster.eks.region,
            },
          },
        },
      ],
    },
  },
};

function(config) (
  local group = config.groups.certManager { name: 'cert-manager' };
  if group.enabled then {
    Helmrelease: if group.helmrelease.create then helpers.helmrelease(config, group),
    Namespace: if group.namespace.create then helpers.namespace(config, group),
    StagingClusterIssuer:
      ClusterIssuer(config,
                    group,
                    'https://acme-staging-v02.api.letsencrypt.org/directory',
                    'letsencrypt-staging'),
    ProductionClusterIssuer:
      ClusterIssuer(config,
                    group,
                    'https://acme-v02.api.letsencrypt.org/directory',
                    'letsencrypt-production'),
    Role: if group.cfrole.create then helpers.iamRole(config, group),
    ManagedPolicy: if group.cfmanagedpolicy.create then ManagedPolicy(config, group),
  }
)

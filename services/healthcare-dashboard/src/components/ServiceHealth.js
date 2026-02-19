import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  Chip,
  Button,
  List,
  ListItem,
  ListItemText,
  Divider,
  CircularProgress,
  Alert,
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  CheckCircle as CheckCircleIcon,
  Error as ErrorIcon,
  Warning as WarningIcon,
} from '@mui/icons-material';
import { healthService } from '../services/api';
import { toast } from 'react-toastify';

const ServiceHealth = () => {
  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState(null);

  useEffect(() => {
    fetchHealthData();
    const interval = setInterval(fetchHealthData, 30000); // Refresh every 30 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchHealthData = async () => {
    try {
      setLoading(true);
      const healthData = await healthService.getAllStatus();
      setServices(healthData);
      setLastUpdated(new Date());
    } catch (error) {
      console.error('Error fetching health data:', error);
      toast.error('Error loading service health data');
    } finally {
      setLoading(false);
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'healthy':
        return <CheckCircleIcon sx={{ color: '#4caf50' }} />;
      case 'unhealthy':
        return <ErrorIcon sx={{ color: '#f44336' }} />;
      default:
        return <WarningIcon sx={{ color: '#ff9800' }} />;
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy':
        return 'success';
      case 'unhealthy':
        return 'error';
      default:
        return 'warning';
    }
  };

  const ServiceCard = ({ service }) => (
    <Card sx={{ height: '100%' }}>
      <CardContent>
        <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
          <Typography variant="h6" component="div">
            {service.name}
          </Typography>
          <Box display="flex" alignItems="center">
            {getStatusIcon(service.status)}
            <Chip
              label={service.status}
              color={getStatusColor(service.status)}
              size="small"
              sx={{ ml: 1 }}
            />
          </Box>
        </Box>
        
        <Divider sx={{ my: 2 }} />
        
        <Typography variant="subtitle2" gutterBottom>
          Health Status:
        </Typography>
        <List dense>
          <ListItem>
            <ListItemText
              primary="Status"
              secondary={service.health?.status || 'Unknown'}
            />
          </ListItem>
          {service.health?.database && (
            <ListItem>
              <ListItemText
                primary="Database"
                secondary={service.health.database}
              />
            </ListItem>
          )}
          {service.health?.uptime && (
            <ListItem>
              <ListItemText
                primary="Uptime"
                secondary={service.health.uptime}
              />
            </ListItem>
          )}
        </List>
        
        <Typography variant="subtitle2" gutterBottom>
          Readiness Status:
        </Typography>
        <List dense>
          <ListItem>
            <ListItemText
              primary="Status"
              secondary={service.readiness?.status || 'Unknown'}
            />
          </ListItem>
          {service.readiness?.database && (
            <ListItem>
              <ListItemText
                primary="Database Connection"
                secondary={service.readiness.database}
              />
            </ListItem>
          )}
        </List>
        
        {service.health?.error && (
          <Alert severity="error" sx={{ mt: 2 }}>
            {service.health.error}
          </Alert>
        )}
      </CardContent>
    </Card>
  );

  const healthyServices = services.filter(s => s.status === 'healthy').length;
  const totalServices = services.length;

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">Service Health Monitor</Typography>
        <Button
          startIcon={<RefreshIcon />}
          onClick={fetchHealthData}
          disabled={loading}
        >
          Refresh
        </Button>
      </Box>

      {lastUpdated && (
        <Typography variant="body2" color="text.secondary" mb={2}>
          Last updated: {lastUpdated.toLocaleTimeString()}
        </Typography>
      )}

      <Grid container spacing={2} mb={4}>
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Overall Health
              </Typography>
              <Box display="flex" alignItems="center">
                <CircularProgress
                  variant="determinate"
                  value={(healthyServices / totalServices) * 100}
                  size={60}
                  sx={{ mr: 2 }}
                />
                <Box>
                  <Typography variant="h4">
                    {healthyServices}/{totalServices}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Services Healthy
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Infrastructure
              </Typography>
              <List dense>
                <ListItem>
                  <ListItemText
                    primary="Kubernetes Cluster"
                    secondary="Active"
                  />
                  <CheckCircleIcon sx={{ color: '#4caf50' }} />
                </ListItem>
                <ListItem>
                  <ListItemText
                    primary="Istio Service Mesh"
                    secondary="Operational"
                  />
                  <CheckCircleIcon sx={{ color: '#4caf50' }} />
                </ListItem>
                <ListItem>
                  <ListItemText
                    primary="Monitoring Stack"
                    secondary="Prometheus + Grafana"
                  />
                  <CheckCircleIcon sx={{ color: '#4caf50' }} />
                </ListItem>
              </List>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {loading ? (
        <Box display="flex" justifyContent="center" py={4}>
          <CircularProgress />
        </Box>
      ) : (
        <Grid container spacing={3}>
          {services.map((service, index) => (
            <Grid item xs={12} md={4} key={index}>
              <ServiceCard service={service} />
            </Grid>
          ))}
          {services.length === 0 && (
            <Grid item xs={12}>
              <Alert severity="warning">
                No service health data available. Check if services are running.
              </Alert>
            </Grid>
          )}
        </Grid>
      )}
    </Box>
  );
};

export default ServiceHealth;
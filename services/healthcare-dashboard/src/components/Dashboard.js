import React, { useState, useEffect } from 'react';
import {
  Grid,
  Paper,
  Typography,
  Box,
  Card,
  CardContent,
  CircularProgress,
} from '@mui/material';
import {
  People as PeopleIcon,
  Event as EventIcon,
  Description as DescriptionIcon,
  TrendingUp as TrendingUpIcon,
} from '@mui/icons-material';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { patientsService, appointmentsService, medicalRecordsService, healthService } from '../services/api';
import { toast } from 'react-toastify';

const Dashboard = () => {
  const [stats, setStats] = useState({
    patients: 0,
    appointments: 0,
    medicalRecords: 0,
    loading: true,
  });
  
  const [servicesHealth, setServicesHealth] = useState([]);
  const [chartData, setChartData] = useState([]);

  useEffect(() => {
    fetchDashboardData();
    fetchServicesHealth();
  }, []);

  const fetchDashboardData = async () => {
    try {
      const [patientsResponse, appointmentsResponse, recordsResponse] = await Promise.allSettled([
        patientsService.getAll(),
        appointmentsService.getAll(),
        medicalRecordsService.getAll(),
      ]);

      const patientsCount = patientsResponse.status === 'fulfilled' ? patientsResponse.value.data.length : 0;
      const appointmentsCount = appointmentsResponse.status === 'fulfilled' ? appointmentsResponse.value.data.length : 0;
      const recordsCount = recordsResponse.status === 'fulfilled' ? recordsResponse.value.data.length : 0;

      setStats({
        patients: patientsCount,
        appointments: appointmentsCount,
        medicalRecords: recordsCount,
        loading: false,
      });

      // Prepare chart data
      setChartData([
        { name: 'Patients', count: patientsCount, color: '#2196f3' },
        { name: 'Appointments', count: appointmentsCount, color: '#4caf50' },
        { name: 'Medical Records', count: recordsCount, color: '#ff9800' },
      ]);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      toast.error('Error loading dashboard data');
      setStats(prev => ({ ...prev, loading: false }));
    }
  };

  const fetchServicesHealth = async () => {
    try {
      const healthData = await healthService.getAllStatus();
      setServicesHealth(healthData);
    } catch (error) {
      console.error('Error fetching services health:', error);
      toast.error('Error loading services health data');
    }
  };

  const StatCard = ({ title, value, icon, color, loading }) => (
    <Card sx={{ height: '100%', backgroundColor: color, color: 'white' }}>
      <CardContent>
        <Box display="flex" alignItems="center" justifyContent="space-between">
          <Box>
            <Typography variant="h6" component="div" gutterBottom>
              {title}
            </Typography>
            {loading ? (
              <CircularProgress size={24} sx={{ color: 'white' }} />
            ) : (
              <Typography variant="h3" component="div">
                {value}
              </Typography>
            )}
          </Box>
          <Box>{icon}</Box>
        </Box>
      </CardContent>
    </Card>
  );

  const HealthIndicator = ({ name, status }) => (
    <Box display="flex" alignItems="center" justifyContent="space-between" mb={1}>
      <Typography variant="body2">{name}</Typography>
      <Box
        sx={{
          width: 12,
          height: 12,
          borderRadius: '50%',
          backgroundColor: status === 'healthy' ? '#4caf50' : '#f44336',
        }}
      />
    </Box>
  );

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Healthcare Services Dashboard
      </Typography>
      <Typography variant="body1" color="text.secondary" paragraph>
        Welcome to the Healthcare Microservices Platform. Monitor patients, appointments, medical records, and service health.
      </Typography>

      <Grid container spacing={3} mb={4}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Patients"
            value={stats.patients}
            icon={<PeopleIcon sx={{ fontSize: 40 }} />}
            color="#2196f3"
            loading={stats.loading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Appointments"
            value={stats.appointments}
            icon={<EventIcon sx={{ fontSize: 40 }} />}
            color="#4caf50"
            loading={stats.loading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Medical Records"
            value={stats.medicalRecords}
            icon={<DescriptionIcon sx={{ fontSize: 40 }} />}
            color="#ff9800"
            loading={stats.loading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Services Healthy"
            value={`${servicesHealth.filter(s => s.status === 'healthy').length}/${servicesHealth.length}`}
            icon={<TrendingUpIcon sx={{ fontSize: 40 }} />}
            color="#9c27b0"
            loading={false}
          />
        </Grid>
      </Grid>

      <Grid container spacing={3}>
        <Grid item xs={12} md={8}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Data Overview
            </Typography>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="count" fill="#2196f3" />
              </BarChart>
            </ResponsiveContainer>
          </Paper>
        </Grid>
        
        <Grid item xs={12} md={4}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Microservices Status
            </Typography>
            <Box mt={2}>
              {servicesHealth.map((service, index) => (
                <HealthIndicator
                  key={index}
                  name={service.name}
                  status={service.status}
                />
              ))}
            </Box>
            <Box mt={3}>
              <Typography variant="body2" color="text.secondary">
                <strong>Architecture:</strong>
              </Typography>
              <Typography variant="body2" color="text.secondary" mt={1}>
                • Kubernetes Orchestration<br />
                • Istio Service Mesh<br />
                • MongoDB & PostgreSQL<br />
                • Node.js, Python, Go Services<br />
                • React Frontend
              </Typography>
            </Box>
          </Paper>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;